/* Plant Vision — Admin dashboard (vanilla JS, không phụ thuộc framework) */

const API = '';
const state = {
  usersPage: 1,
  usersLimit: 50,
  usersTotal: 0,
  usersQuery: '',
  usersSort: 'last_seen',
  plantsPage: 1,
  plantsLimit: 100,
  plantsTotal: 0,
  plantsQuery: '',
  plantsLocated: false,
};

// ── Helpers ────────────────────────────────────────────────────────────────

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => Array.from(document.querySelectorAll(sel));

async function api(path) {
  const res = await fetch(API + path);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json();
}

function esc(value) {
  if (value === null || value === undefined) return '';
  return String(value)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function shortDate(value) {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return esc(value);
  return d.toLocaleString('vi-VN', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

function shortId(value) {
  const s = String(value || '');
  return s.length > 14 ? s.slice(0, 12) + '…' : s;
}

function pct(value) {
  if (value === null || value === undefined || value === '') return '—';
  const n = Number(value);
  if (Number.isNaN(n)) return esc(value);
  return n > 0 && n <= 1 ? (n * 100).toFixed(1) + '%' : n.toFixed(1) + '%';
}

// ── Tabs ───────────────────────────────────────────────────────────────────

$$('.tab').forEach((btn) => {
  btn.addEventListener('click', () => {
    $$('.tab').forEach((b) => b.classList.remove('active'));
    $$('.tab-panel').forEach((p) => p.classList.remove('active'));
    btn.classList.add('active');
    $('#tab-' + btn.dataset.tab).classList.add('active');
    if (btn.dataset.tab === 'plants') loadPlants();
    if (btn.dataset.tab === 'chats') loadChats();
  });
});

// ── Dashboard ──────────────────────────────────────────────────────────────

async function loadDashboard() {
  try {
    const s = await api('/api/stats');

    $('#statCards').innerHTML = [
      card('Người dùng', s.users, false),
      card('Người dùng hoạt động', s.active_users, false),
      card('Lần nhận diện', s.plants, true),
      card('Có tọa độ GPS', s.located_plants, true),
      card('Tin nhắn chat', s.chats, true),
    ].join('');

    const last = s.last_sync;
    $('#syncInfo').textContent = last
      ? `Đồng bộ: ${shortDate(last.ended_at)} · ${last.plants} cây · ${last.users} user`
      : 'Chưa có dữ liệu — chạy sync_mongo.py';

    const users = await api('/api/users?limit=8&sort=plant_count&order=desc');
    $('#topUsers').innerHTML = users.items.length
      ? users.items.map((u) => `
        <div class="list-item">
          <span class="name">${esc(u.display_name || u.username || shortId(u.user_id))}</span>
          <span class="meta">${u.plant_count} cây · ${u.chat_count} chat</span>
        </div>`).join('')
      : '<div class="empty">Chưa có dữ liệu</div>';

    const plants = await api('/api/plants?limit=8');
    const byName = {};
    plants.items.forEach((p) => {
      const key = p.name || '(không rõ)';
      byName[key] = (byName[key] || 0) + 1;
    });
    const sorted = Object.entries(byName).sort((a, b) => b[1] - a[1]).slice(0, 8);
    $('#topPlants').innerHTML = sorted.length
      ? sorted.map(([name, count]) => `
        <div class="list-item">
          <span class="name">${esc(name)}</span>
          <span class="meta">${count} lần</span>
        </div>`).join('')
      : '<div class="empty">Chưa có dữ liệu</div>';

    const log = await api('/api/sync-log');
    $('#syncLog').innerHTML = log.items.length
      ? log.items.map((r) => `
        <div class="list-item">
          <span class="name">${esc(shortDate(r.started_at))} → ${esc(shortDate(r.ended_at))}</span>
          <span class="meta">
            ${r.users} user · ${r.plants} cây · ${r.chats} chat
            <span class="badge ${r.status === 'ok' ? '' : 'warn'}">${esc(r.status)}</span>
          </span>
        </div>`).join('')
      : '<div class="empty">Chưa có lần đồng bộ nào</div>';
  } catch (err) {
    $('#syncInfo').textContent = 'Lỗi: ' + err.message;
  }
}

function card(label, value, accent) {
  return `<div class="card${accent ? ' accent' : ''}">
    <div class="card-label">${label}</div>
    <div class="card-value">${value ?? 0}</div>
  </div>`;
}

// ── Users ──────────────────────────────────────────────────────────────────

async function loadUsers(page = state.usersPage) {
  state.usersPage = page;
  const params = new URLSearchParams({
    page, limit: state.usersLimit,
    sort: state.usersSort, order: 'desc',
  });
  if (state.usersQuery) params.set('q', state.usersQuery);

  try {
    const data = await api('/api/users?' + params.toString());
    state.usersTotal = data.total;
    const body = $('#usersBody');

    if (!data.items.length) {
      body.innerHTML = '<tr><td colspan="9" class="empty">Không tìm thấy người dùng nào</td></tr>';
    } else {
      body.innerHTML = data.items.map((u) => `
        <tr>
          <td>${esc(u.username || '—')}</td>
          <td>${esc(u.display_name || '—')}</td>
          <td>${esc(u.email || '—')}</td>
          <td>${esc(u.phone_number || '—')}</td>
          <td class="mono">${esc(shortId(u.user_id))}</td>
          <td><span class="badge">${u.plant_count ?? 0}</span></td>
          <td><span class="badge mute">${u.chat_count ?? 0}</span></td>
          <td>${esc(shortDate(u.last_seen))}</td>
          <td><button class="btn primary" onclick="openUser('${esc(u.user_id)}')">Chi tiết</button></td>
        </tr>`).join('');
    }
    renderPager('#usersPager', state.usersTotal, state.usersLimit, page, loadUsers);
  } catch (err) {
    $('#usersBody').innerHTML = `<tr><td colspan="9" class="empty">Lỗi: ${esc(err.message)}</td></tr>`;
  }
}

// ── Plants ─────────────────────────────────────────────────────────────────

async function loadPlants(page = state.plantsPage) {
  state.plantsPage = page;
  const params = new URLSearchParams({
    page, limit: state.plantsLimit,
  });
  if (state.plantsQuery) params.set('q', state.plantsQuery);
  if (state.plantsLocated) params.set('located', '1');

  try {
    const data = await api('/api/plants?' + params.toString());
    state.plantsTotal = data.total;
    const body = $('#plantsBody');

    if (!data.items.length) {
      body.innerHTML = '<tr><td colspan="8" class="empty">Chưa có lịch sử nhận diện</td></tr>';
    } else {
      body.innerHTML = data.items.map((p) => {
        const img = p.thumbnail_url || p.image_url;
        const thumb = img
          ? `<img class="thumb" src="${esc(img)}" alt="" loading="lazy" onerror="this.style.visibility='hidden'">`
          : '<span class="badge mute">—</span>';
        const gps = (p.latitude && p.longitude)
          ? `<span class="badge">${Number(p.latitude).toFixed(4)}, ${Number(p.longitude).toFixed(4)}</span>`
          : '<span class="badge mute">Không có</span>';
        return `<tr>
          <td>${thumb}</td>
          <td><strong>${esc(p.name || '—')}</strong></td>
          <td><em>${esc(p.scientific_name || '—')}</em></td>
          <td>${pct(p.confidence)}</td>
          <td>${gps}</td>
          <td class="wrap">${esc(p.notes || '—')}</td>
          <td class="mono">${esc(shortId(p.user_id))}</td>
          <td>${esc(shortDate(p.created_at))}</td>
        </tr>`;
      }).join('');
    }
    renderPager('#plantsPager', state.plantsTotal, state.plantsLimit, page, loadPlants);
  } catch (err) {
    $('#plantsBody').innerHTML = `<tr><td colspan="8" class="empty">Lỗi: ${esc(err.message)}</td></tr>`;
  }
}

// ── Chats ──────────────────────────────────────────────────────────────────

async function loadChats() {
  try {
    const data = await api('/api/chats?limit=200');
    const body = $('#chatsBody');
    if (!data.items.length) {
      body.innerHTML = '<tr><td colspan="6" class="empty">Chưa có lịch sử chat</td></tr>';
      return;
    }
    body.innerHTML = data.items.map((c) => `
      <tr>
        <td class="mono">${esc(shortId(c.user_id))}</td>
        <td class="mono">${esc(shortId(c.conversation_id))}</td>
        <td><span class="badge ${c.sender === 'user' ? '' : 'mute'}">${esc(c.sender || '—')}</span></td>
        <td>${esc(c.msg_type || 'text')}</td>
        <td class="wrap">${esc(c.text_content || c.image_url || '—')}</td>
        <td>${esc(shortDate(c.created_at))}</td>
      </tr>`).join('');
  } catch (err) {
    $('#chatsBody').innerHTML = `<tr><td colspan="6" class="empty">Lỗi: ${esc(err.message)}</td></tr>`;
  }
}

// ── Pager ──────────────────────────────────────────────────────────────────

function renderPager(selector, total, limit, current, loader) {
  const pages = Math.max(1, Math.ceil(total / limit));
  const el = $(selector);
  el.innerHTML = `
    <button ${current <= 1 ? 'disabled' : ''} data-go="${current - 1}">‹ Trước</button>
    <span class="info">Trang ${current} / ${pages} — ${total} bản ghi</span>
    <button ${current >= pages ? 'disabled' : ''} data-go="${current + 1}">Sau ›</button>`;
  el.querySelectorAll('button[data-go]').forEach((b) => {
    b.addEventListener('click', () => loader(Number(b.dataset.go)));
  });
}

// ── Modal chi tiết user ───────────────────────────────────────────────────

async function openUser(userId) {
  const modal = $('#modal');
  const content = $('#modalContent');
  content.innerHTML = '<div class="empty">Đang tải…</div>';
  modal.classList.remove('hidden');

  try {
    const u = await api('/api/users/' + encodeURIComponent(userId));
    const plants = u.plants || [];
    const chats = u.chats || [];

    content.innerHTML = `
      <h3>${esc(u.display_name || u.username || 'Người dùng')}</h3>
      <dl class="kv">
        <dt>Username</dt><dd>${esc(u.username || '—')}</dd>
        <dt>Email</dt><dd>${esc(u.email || '—')}</dd>
        <dt>Số điện thoại</dt><dd>${esc(u.phone_number || '—')}</dd>
        <dt>User ID</dt><dd class="mono">${esc(u.user_id)}</dd>
        <dt>Nguồn</dt><dd><span class="badge ${u.source === 'mongo+api' ? '' : 'mute'}">${esc(u.source || 'mongo')}</span></dd>
        <dt>Lần nhận diện</dt><dd>${u.plant_count ?? plants.length}</dd>
        <dt>Tin nhắn chat</dt><dd>${u.chat_count ?? chats.length}</dd>
        <dt>Hoạt động đầu</dt><dd>${esc(shortDate(u.first_seen))}</dd>
        <dt>Hoạt động gần nhất</dt><dd>${esc(shortDate(u.last_seen))}</dd>
      </dl>

      <h4>Lịch sử nhận diện (${plants.length})</h4>
      ${plants.length ? `
        <div class="table-wrap"><table>
          <thead><tr><th>Tên cây</th><th>Khoa học</th><th>Tin cậy</th><th>GPS</th><th>Thời điểm</th></tr></thead>
          <tbody>${plants.map((p) => `
            <tr>
              <td>${esc(p.name || '—')}</td>
              <td><em>${esc(p.scientific_name || '—')}</em></td>
              <td>${pct(p.confidence)}</td>
              <td>${(p.latitude && p.longitude)
                ? esc(Number(p.latitude).toFixed(4) + ', ' + Number(p.longitude).toFixed(4))
                : '—'}</td>
              <td>${esc(shortDate(p.created_at))}</td>
            </tr>`).join('')}</tbody>
        </table></div>` : '<div class="empty">Chưa có</div>'}

      <h4>Trò chuyện AI (${chats.length})</h4>
      ${chats.length ? `
        <div class="table-wrap"><table>
          <thead><tr><th>Người gửi</th><th>Nội dung</th><th>Thời điểm</th></tr></thead>
          <tbody>${chats.map((c) => `
            <tr>
              <td><span class="badge ${c.sender === 'user' ? '' : 'mute'}">${esc(c.sender || '—')}</span></td>
              <td class="wrap">${esc(c.text_content || c.image_url || '—')}</td>
              <td>${esc(shortDate(c.created_at))}</td>
            </tr>`).join('')}</tbody>
        </table></div>` : '<div class="empty">Chưa có</div>'}`;
  } catch (err) {
    content.innerHTML = `<div class="empty">Lỗi: ${esc(err.message)}</div>`;
  }
}

$('#modalClose').addEventListener('click', () => $('#modal').classList.add('hidden'));
$('#modal').addEventListener('click', (e) => {
  if (e.target.id === 'modal') $('#modal').classList.add('hidden');
});

// ── Toolbar events ─────────────────────────────────────────────────────────

$('#userSearchBtn').addEventListener('click', () => {
  state.usersQuery = $('#userSearch').value.trim();
  loadUsers(1);
});
$('#userSearch').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') { state.usersQuery = $('#userSearch').value.trim(); loadUsers(1); }
});
$('#userSort').addEventListener('change', (e) => {
  state.usersSort = e.target.value;
  loadUsers(1);
});

$('#plantSearchBtn').addEventListener('click', () => {
  state.plantsQuery = $('#plantSearch').value.trim();
  loadPlants(1);
});
$('#plantSearch').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') { state.plantsQuery = $('#plantSearch').value.trim(); loadPlants(1); }
});
$('#onlyLocated').addEventListener('change', (e) => {
  state.plantsLocated = e.target.checked;
  loadPlants(1);
});

$('#refreshBtn').addEventListener('click', () => {
  loadDashboard();
  loadUsers();
  if ($('#tab-plants').classList.contains('active')) loadPlants();
});

// ── Khởi tạo ───────────────────────────────────────────────────────────────

loadDashboard();
loadUsers();
