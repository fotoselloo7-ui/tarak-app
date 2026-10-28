<?php

// Copy an existing LOCAL MySQL database into a new development database.
// The source is only read. The SQL backup and credentials remain ignored.
if (PHP_SAPI !== 'cli' || count($argv) !== 3) {
    fwrite(STDERR, "Usage: php scripts/copy-local-database.php SOURCE_BACKEND NEW_LOCAL_DATABASE\n");
    exit(1);
}
$root = dirname(__DIR__);
require $root . '/tarak-backend/vendor/autoload.php';
$source = realpath($argv[1]);
$target = $argv[2];
if (!$source || !preg_match('/^[a-zA-Z0-9_]+$/', $target)) {
    throw new RuntimeException('Invalid source directory or destination database name.');
}
$env = Dotenv\Dotenv::parse(file_get_contents($source . '/.env'));
if (($env['APP_ENV'] ?? '') !== 'local' || ($env['DB_CONNECTION'] ?? '') !== 'mysql'
    || !in_array($env['DB_HOST'] ?? '', ['127.0.0.1', 'localhost', '::1'], true)
    || !empty($env['DB_URL']) || !preg_match('/^[a-zA-Z0-9_]+$/', $env['DB_DATABASE'] ?? '')
    || ($env['DB_DATABASE'] ?? '') === $target) {
    throw new RuntimeException('Only a distinct local MySQL destination is allowed.');
}
$pdo = new PDO('mysql:host=' . $env['DB_HOST'] . ';port=' . ($env['DB_PORT'] ?? '3306') . ';charset=utf8mb4',
    $env['DB_USERNAME'], $env['DB_PASSWORD'] ?? '', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$exists = $pdo->prepare('SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=?');
$exists->execute([$target]);
if ($exists->fetchColumn()) {
    throw new RuntimeException('Destination already exists; refusing to overwrite it.');
}
$backupDir = $root . '/.tools/local-db-backups/' . date('Ymd-His');
mkdir($backupDir, 0700, true);
$dump = $backupDir . '/source.sql';
$options = $backupDir . '/client.cnf';
$quote = static fn ($s) => '"' . str_replace(["\\", '"', "\n", "\r"], ["\\\\", '\\"', '\\n', '\\r'], $s) . '"';
$contents = "[client]\nprotocol=tcp\n";
foreach (['host' => 'DB_HOST', 'port' => 'DB_PORT', 'user' => 'DB_USERNAME', 'password' => 'DB_PASSWORD'] as $key => $var) {
    $contents .= $key . '=' . $quote($env[$var] ?? ($key === 'port' ? '3306' : '')) . "\n";
}
file_put_contents($options, $contents);
$run = static function (array $command, $input = null): void {
    $process = proc_open($command, [0 => $input ?? ['pipe', 'r'], 1 => STDOUT, 2 => STDERR], $pipes, null, null, ['bypass_shell' => true]);
    if (!is_resource($process)) {
        throw new RuntimeException('Could not launch MySQL client.');
    }
    if (isset($pipes[0])) fclose($pipes[0]);
    if (proc_close($process) !== 0) throw new RuntimeException('MySQL client failed; existing databases remain untouched.');
};
try {
    $run(['mysqldump', '--defaults-extra-file=' . $options, '--single-transaction', '--skip-lock-tables',
        '--no-tablespaces', '--set-gtid-purged=OFF', '--column-statistics=0', '--result-file=' . $dump, $env['DB_DATABASE']]);
    $pdo->exec('CREATE DATABASE `' . $target . '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
    $run(['mysql', '--defaults-extra-file=' . $options, '--default-character-set=utf8mb4', $target], ['file', $dump, 'r']);
    $sourceTables = $pdo->query('SHOW TABLES FROM `' . $env['DB_DATABASE'] . '`')->fetchAll(PDO::FETCH_COLUMN);
    $counts = [];
    foreach ($sourceTables as $table) {
        $safe = str_replace('`', '``', $table);
        $before = (int) $pdo->query('SELECT COUNT(*) FROM `' . $env['DB_DATABASE'] . '`.`' . $safe . '`')->fetchColumn();
        $after = (int) $pdo->query('SELECT COUNT(*) FROM `' . $target . '`.`' . $safe . '`')->fetchColumn();
        if ($before !== $after) throw new RuntimeException('Copy count mismatch: ' . $table);
        $counts[$table] = $after;
    }
    file_put_contents($backupDir . '/verification.json', json_encode(['tables' => $counts, 'sha256' => hash_file('sha256', $dump)], JSON_PRETTY_PRINT));
    $localPath = $root . '/tarak-backend/.env';
    $local = file_get_contents($localPath);
    copy($localPath, $backupDir . '/previous-local.env');
    $overrides = array_intersect_key($env, array_flip(['APP_KEY', 'DB_HOST', 'DB_PORT', 'DB_USERNAME', 'DB_PASSWORD']));
    $overrides += ['DB_CONNECTION' => 'mysql', 'DB_DATABASE' => $target];
    foreach ($overrides as $key => $value) {
        $line = $key . '=' . $quote($value);
        $pattern = '/^' . preg_quote($key, '/') . '=.*$/m';
        $local = preg_match($pattern, $local) ? preg_replace_callback($pattern, fn () => $line, $local) : $local . "\n" . $line;
    }
    file_put_contents($localPath, $local);
    echo 'Local database copied. Verified ' . count($counts) . ' tables; users=' . $counts['users'] . '; providers=' . $counts['provider_profiles'] . ".\n";
    echo 'Backup: ' . $backupDir . "\n";
} finally {
    if (is_file($options)) unlink($options);
}
