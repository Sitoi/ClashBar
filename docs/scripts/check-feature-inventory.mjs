#!/usr/bin/env node
/**
 * Structural check: feature inventory MDX covers major product areas
 * and navigation surfaces the inventory page. Drives real docs files.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const docsDir = path.join(__dirname, '..', 'content', 'docs');

function read(name) {
  return fs.readFileSync(path.join(docsDir, name), 'utf8');
}

const features = read('features.mdx');
const index = read('index.mdx');
const meta = JSON.parse(read('meta.json'));

const areas = {
  menu_tabs: ['节点', '分流', '连接', '日志', '设置'],
  core_lifecycle: ['启动', '停止', '内核'],
  local_config: ['本地', 'YAML'],
  remote_subscription: ['订阅'],
  proxy_groups_latency: ['代理组', '延迟'],
  system_proxy: ['系统代理'],
  tun: ['TUN'],
  bypass: ['绕过'],
  ssid_strategy: ['SSID'],
  remote_machine: ['远程机器'],
  status_bar: ['状态栏'],
  traffic: ['流量'],
  launch_at_login: ['开机自启'],
  maintenance: ['Geo', 'DNS'],
  terminal: ['终端'],
  modes: ['全局', '直连'],
  language_appearance: ['界面语言', '外观'],
  panel_pin: ['固定'],
  providers: ['代理提供者'],
  keyboard_shortcuts: ['快捷键', '⌘'],
  homebrew_install: ['Homebrew', 'brew'],
  config_discovery: ['.yaml', '文件名排序'],
  typical_scenarios: ['日常办公', '故障排查', '订阅维护'],
};

const requiredPages = [
  'features',
  'ssid-strategy',
  'remote-machine',
  'settings',
  'quick-start',
  'configuration',
  'daily-use',
  'network-mode',
  'troubleshooting',
  'about',
];

let failed = 0;

for (const [name, keys] of Object.entries(areas)) {
  const hit = keys.some((k) => features.includes(k));
  const lines = features.split('\n').filter((ln) => keys.some((k) => ln.includes(k)));
  const descriptive = lines.some((ln) => ln.length >= 12);
  if (!hit || !descriptive) {
    console.error(`FAIL area ${name}`);
    failed += 1;
  } else {
    console.log(`PASS area ${name}`);
  }
}

for (const slug of requiredPages) {
  const file = path.join(docsDir, `${slug}.mdx`);
  if (!fs.existsSync(file)) {
    console.error(`FAIL missing page ${slug}.mdx`);
    failed += 1;
    continue;
  }
  if (!meta.pages.includes(slug)) {
    console.error(`FAIL nav missing ${slug}`);
    failed += 1;
  } else {
    console.log(`PASS page+nav ${slug}`);
  }
}

if (!index.includes('features')) {
  console.error('FAIL index does not link features');
  failed += 1;
} else {
  console.log('PASS index links features');
}

for (const href of [
  './daily-use',
  './configuration',
  './network-mode',
  './ssid-strategy',
  './remote-machine',
  './settings',
  './troubleshooting',
  './about',
]) {
  if (!features.includes(href)) {
    console.error(`FAIL features missing link ${href}`);
    failed += 1;
  } else {
    console.log(`PASS inventory link ${href}`);
  }
}

// README-aligned coverage on specific pages
const quickStart = read('quick-start.mdx');
const config = read('configuration.mdx');
const faq = read('troubleshooting.mdx');
const about = read('about.mdx');

const readmeChecks = [
  ['quick-start Homebrew', quickStart.includes('brew install --cask clashbar')],
  ['quick-start dual core path', quickStart.includes('含 Core') && quickStart.includes('无 Core')],
  ['quick-start uninstall', quickStart.includes('uninstall')],
  ['quick-start cache.db', quickStart.includes('cache.db')],
  ['config discovery yml', config.includes('.yml') && config.includes('文件名排序')],
  ['faq MMDB', faq.includes('MMDB') || faq.includes('mmdb')],
  ['faq 401', faq.includes('401')],
  ['faq node no change', faq.includes('切换节点后')],
  ['about volume table', about.includes('2.7 MB') && about.includes('体积')],
  ['about telegram', about.includes('t.me/clashbars')],
  ['about GPL', about.includes('GPL-3.0')],
  ['index telegram', index.includes('t.me/clashbars')],
];

for (const [name, ok] of readmeChecks) {
  if (!ok) {
    console.error(`FAIL readme ${name}`);
    failed += 1;
  } else {
    console.log(`PASS readme ${name}`);
  }
}

if (failed > 0) {
  console.error(`\nFAILED ${failed} checks`);
  process.exit(1);
}
console.log('\nALL_PASS');
