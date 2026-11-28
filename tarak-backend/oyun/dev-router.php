<?php
// Yalnızca yerel geliştirme: canlıdaki .htaccess korumalarını taklit eder.
$yol = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if (preg_match('#^/(inc|data)(/|$)#i', $yol) || preg_match('#/\.#', $yol)) {
    http_response_code(403);
    echo 'Erisim yok';
    return true;
}
return false;
