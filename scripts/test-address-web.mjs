import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {execFileSync} from 'node:child_process';
import {test} from 'node:test';

const root = new URL('../tarak.app/', import.meta.url);
const read = name => fs.readFileSync(new URL(`assets/${name}`, root), 'utf8');
const main = read('index-Bj5sn6If.js');
const job = read('JobCreate-BRz7Wn-F.js');
const jsx = (type, props) => ({type, props});
const elements = node => !node || typeof node !== 'object' ? [] : Array.isArray(node)
  ? node.flatMap(elements) : [node, ...elements(node.props?.children)];
const text = node => typeof node === 'string' ? node : !node || typeof node !== 'object' ? ''
  : Array.isArray(node) ? node.map(text).join(' ') : text(node.props?.children);

test('the closing home CTA routes customers to scheduled appointments; guest auth callback remains usable', () => {
  const expression = main.match(/provider_cta:s\.jsx\(ya,\{onPrimary:(.*?),onProvider:/)?.[1];
  assert.ok(expression);
  for (const role of ['CUSTOMER', null]) {
    const routes = [];
    let auth = 0;
    const click = vm.runInNewContext(`(${expression})`, {
      r: role ? {role} : null, w: {CUSTOMER: 'CUSTOMER'},
      i: (...args) => routes.push(args), c: () => auth++,
    });
    click();
    if (role) assert.equal(JSON.stringify(routes), JSON.stringify([['customer/create-job', {mode: 'scheduled'}]]));
    else assert.equal(auth, 1);
  }
});

test('address writes notify mounted nearby lists only after successful completion', async () => {
  const source = main.slice(main.indexOf('function m(t,e={})'), main.indexOf('const K={get:'));
  assert.ok(source.startsWith('function m('));
  const events = [];
  const result = {success: true};
  const context = {te: {get: () => 'token'}, Dt: 'token', ze: new Map(), ge: new Map(),
    et: async () => result, window: {dispatchEvent: event => events.push(event.type)}, Event};
  const request = vm.runInNewContext(`(${source})`, context);
  assert.equal(await request('/customer/addresses/8', {method: 'PUT'}), result);
  assert.deepEqual(events, ['tarak:addresses-changed']);
  result.success = false;
  await request('/customer/profile', {method: 'PUT'});
  result.success = true;
  await request('/customer/appointments', {method: 'POST'});
  assert.equal(events.length, 1);
  context.et = async () => { throw new Error('network'); };
  await assert.rejects(request('/customer/addresses/8', {method: 'PUT'}));
  assert.equal(events.length, 1);
});

test('scheduled provider queries use the chosen saved address even if device origin exists', async () => {
  const source = job.slice(job.indexOf('const At=') + 9, job.indexOf(',qt='));
  const effects = [], queries = [];
  const context = {
    z: {useState: value => [value, () => {}], useEffect: callback => effects.push(callback)},
    e: {jsx, jsxs: jsx}, Be: {q: '', minRating: 0, maxDistanceKm: 0, sort: 'relevance'},
    ft: () => ({origin: {lat: 36.49, lng: 32.09}, useDevice: () => { throw new Error('device override'); }}),
    vt: value => value, jt: (filters, origin) => ({lat: origin?.lat, lng: origin?.lng}),
    se: {customer: {getScheduledProviders: async params => { queries.push(params); return {success: true, data: []}; }}},
    Nt: () => [], kt: () => [], St: () => false, zt: 'filters', wt: 'rotation',
  };
  const component = vm.runInNewContext(`(${source})`, context);
  const tree = component({providerType: 'barber', serviceIds: [1],
    addressOrigin: {lat: 41.06, lng: 28.99}, customerAddressId: 8, onSelect() {}});
  effects[0]();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(queries[0].filters.customer_address_id, 8);
  assert.equal(queries[0].filters.lat, 41.06);
  assert.equal(queries[0].filters.sort, 'distance');
  assert.equal(queries[0].filters.max_distance_km, 50);
  assert.equal(elements(tree).find(node => node.type === 'filters').props.onUseDevice, undefined);
});

test('the scheduled web form starts with saved addresses and cannot submit before an explicit choice', () => {
  const source = job.slice(job.indexOf(',qt=') + 4, job.indexOf(';export{qt as default}'));
  const states = [], effects = [];
  const react = {useState: initial => {
    const value = typeof initial === 'function' ? initial() : initial;
    states.push(value); return [value, () => {}];
  }, useEffect: callback => effects.push(callback)};
  const context = {r: react, bt: {getCurrentUser: () => ({city: 'İstanbul', district: 'Şişli'})},
    d: {SCHEDULED: 'scheduled', INSTANT: 'instant'}, p: {CASH: 'CASH', ONLINE: 'ONLINE'},
    e: {jsx, jsxs: jsx, Fragment: 'fragment'}};
  for (const name of ['je','Se','ke','te','L','Me','Ne','ee','Et','pt','yt','$e','ze']) context[name] = name;
  const component = vm.runInNewContext(`(${source})`, context);
  const tree = component({onNavigate() {}, params: {mode: 'scheduled'}});
  const nodes = elements(tree);
  const form = nodes.find(node => node.type === 'form');
  assert.ok(text(form.props.children[0]).includes('Hizmet Adresi & Konum'));
  assert.ok(text(form.props.children[1]).includes('Hizmet Seçimi'));
  assert.ok(text(tree).includes('İstediğin Güne Randevu Al'));
  assert.equal(nodes.find(node => node.props?.type === 'submit').props.disabled, true);
  assert.ok(text(tree).includes('Önce yukarıdan kayıtlı adresinizi seçin.'));
});

test('all web modules parse and use one consistent cache version', () => {
  const version = '20261030-nearby-fallback1';
  for (const name of fs.readdirSync(new URL('assets/', root)).filter(name => name.endsWith('.js') && !name.includes('sync-conflict'))) {
    const file = new URL(`assets/${name}`, root);
    execFileSync(process.execPath, ['--check', file.pathname.replace(/^\/(\w:)/, '$1')], {stdio: 'pipe'});
    for (const match of fs.readFileSync(file, 'utf8').matchAll(/["'](?:\.\/|\/assets\/|assets\/)[A-Za-z0-9_./-]+\.js\?v=([^"']+)/g)) {
      assert.equal(match[1], version, name);
    }
  }
  assert.ok(fs.readFileSync(new URL('index.html', root), 'utf8').includes(`index-Bj5sn6If.js?v=${version}`));
});
