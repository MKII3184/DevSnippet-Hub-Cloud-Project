// State
let currentUser = null;
let currentToken = localStorage.getItem('token') || null;
let currentFilter = {
  status: 'all',
  language: 'all',
  search: ''
};
let cachedSnippets = [];

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
  setupEventListeners();
  await checkAuth();
  await loadStats();
  await loadSnippets();
  await checkSystemHealth();
});

function setupEventListeners() {
  const searchInput = document.getElementById('search-input');
  let searchTimeout = null;
  searchInput.addEventListener('input', (e) => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      currentFilter.search = e.target.value.trim();
      loadSnippets();
    }, 300);
  });

  const langFilter = document.getElementById('filter-language');
  langFilter.addEventListener('change', (e) => {
    currentFilter.language = e.target.value;
    loadSnippets();
  });
}

// Authentication Handlers
async function checkAuth() {
  if (!currentToken) {
    updateAuthUI(null);
    return;
  }

  try {
    const res = await fetch('/api/auth/me', {
      headers: { 'Authorization': `Bearer ${currentToken}` }
    });
    if (res.ok) {
      const data = await res.json();
      currentUser = data.user;
      updateAuthUI(currentUser);
    } else {
      localStorage.removeItem('token');
      currentToken = null;
      updateAuthUI(null);
    }
  } catch {
    updateAuthUI(null);
  }
}

function updateAuthUI(user) {
  const guestSec = document.getElementById('auth-guest-section');
  const userSec = document.getElementById('auth-user-section');
  const btnCreate = document.getElementById('btn-create-snippet');

  if (user) {
    guestSec.classList.add('hidden');
    userSec.classList.remove('hidden');
    document.getElementById('user-display-name').textContent = user.username;
    document.getElementById('user-avatar').textContent = user.username.charAt(0).toUpperCase();
    btnCreate.classList.remove('hidden');
  } else {
    guestSec.classList.remove('hidden');
    userSec.classList.add('hidden');
  }
}

async function handleLogin(e) {
  e.preventDefault();
  const email = document.getElementById('login-email').value;
  const password = document.getElementById('login-password').value;

  try {
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    const data = await res.json();
    if (data.success) {
      currentToken = data.token;
      currentUser = data.user;
      localStorage.setItem('token', data.token);
      updateAuthUI(currentUser);
      closeModal('modal-auth');
      showToast('Đăng nhập thành công! Chào mừng ' + currentUser.username, 'success');
      loadStats();
      loadSnippets();
    } else {
      showToast(data.error || 'Đăng nhập thất bại', 'error');
    }
  } catch (err) {
    showToast('Lỗi kết nối máy chủ: ' + err.message, 'error');
  }
}

async function handleRegister(e) {
  e.preventDefault();
  const username = document.getElementById('reg-username').value;
  const email = document.getElementById('reg-email').value;
  const password = document.getElementById('reg-password').value;

  try {
    const res = await fetch('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, email, password })
    });
    const data = await res.json();
    if (data.success) {
      currentToken = data.token;
      currentUser = data.user;
      localStorage.setItem('token', data.token);
      updateAuthUI(currentUser);
      closeModal('modal-auth');
      showToast('Đăng ký tài khoản thành công!', 'success');
      loadStats();
      loadSnippets();
    } else {
      showToast(data.error || 'Đăng ký thất bại', 'error');
    }
  } catch (err) {
    showToast('Lỗi kết nối máy chủ: ' + err.message, 'error');
  }
}

async function logout() {
  try {
    await fetch('/api/auth/logout', { method: 'POST' });
  } catch (err) {
    console.error(err);
  }
  localStorage.removeItem('token');
  currentToken = null;
  currentUser = null;
  updateAuthUI(null);
  showToast('Đã đăng xuất tài khoản.', 'info');
  loadStats();
  loadSnippets();
}

// Snippets CRUD
async function loadSnippets() {
  const container = document.getElementById('snippets-container');
  const emptyState = document.getElementById('empty-state');

  try {
    let url = `/api/snippets?status=${currentFilter.status}&language=${currentFilter.language}`;
    if (currentFilter.search) {
      url += `&search=${encodeURIComponent(currentFilter.search)}`;
    }

    const headers = {};
    if (currentToken) {
      headers['Authorization'] = `Bearer ${currentToken}`;
    }

    const res = await fetch(url, { headers });
    const data = await res.json();

    if (data.success && data.snippets.length > 0) {
      cachedSnippets = data.snippets;
      emptyState.classList.add('hidden');
      container.classList.remove('hidden');
      renderSnippets(data.snippets);
    } else {
      cachedSnippets = [];
      container.innerHTML = '';
      container.classList.add('hidden');
      emptyState.classList.remove('hidden');
    }
  } catch (err) {
    showToast('Lỗi tải danh sách snippet: ' + err.message, 'error');
  }
}

function renderSnippets(snippets) {
  const container = document.getElementById('snippets-container');
  container.innerHTML = '';

  snippets.forEach(snippet => {
    const isOwner = currentUser && (currentUser.id === snippet.user_id);
    const isPublic = snippet.status === 'public';
    const tagsList = snippet.tags ? snippet.tags.split(',').map(t => t.trim()).filter(Boolean) : [];

    const card = document.createElement('div');
    card.className = 'p-5 rounded-2xl bg-slate-900 border border-slate-800 hover:border-slate-700/80 transition flex flex-col justify-between shadow-xl shadow-black/20';

    // Prism language class
    const langClass = `language-${snippet.language || 'plaintext'}`;

    card.innerHTML = `
      <div>
        <!-- Card Header -->
        <div class="flex items-center justify-between gap-3 mb-3">
          <div class="flex items-center space-x-2">
            <span class="px-2.5 py-1 text-xs font-mono font-semibold rounded-md bg-slate-800 text-emerald-400 border border-slate-700">
              ${escapeHtml(snippet.language.toUpperCase())}
            </span>
            <span class="px-2 py-0.5 text-xs rounded-full ${isPublic ? 'bg-teal-500/10 text-teal-400 border border-teal-500/20' : 'bg-amber-500/10 text-amber-400 border border-amber-500/20'}">
              ${isPublic ? '🌐 Công khai' : '🔒 Riêng tư'}
            </span>
          </div>

          <!-- Actions -->
          <div class="flex items-center space-x-1">
            <button onclick="copySnippetCode(${snippet.id})" title="Sao chép mã" class="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
            </button>
            ${isOwner ? `
              <button onclick="editSnippet(${snippet.id})" title="Chỉnh sửa" class="p-1.5 text-slate-400 hover:text-emerald-400 hover:bg-slate-800 rounded-lg transition">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/></svg>
              </button>
              <button onclick="deleteSnippet(${snippet.id})" title="Xóa" class="p-1.5 text-slate-400 hover:text-red-400 hover:bg-slate-800 rounded-lg transition">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>
              </button>
            ` : ''}
          </div>
        </div>

        <!-- Title & Desc -->
        <h4 class="text-base font-bold text-slate-100 hover:text-emerald-400 transition cursor-pointer mb-1.5" onclick="copySnippetCode(${snippet.id})">
          ${escapeHtml(snippet.title)}
        </h4>
        ${snippet.description ? `<p class="text-xs text-slate-400 mb-3 line-clamp-2">${escapeHtml(snippet.description)}</p>` : ''}

        <!-- Code Block with Prism -->
        <div class="relative group my-3">
          <pre class="${langClass} custom-scroll"><code class="${langClass}">${escapeHtml(snippet.code)}</code></pre>
        </div>

        <!-- Tags -->
        ${tagsList.length > 0 ? `
          <div class="flex flex-wrap gap-1.5 mt-2">
            ${tagsList.map(tag => `<span class="text-[11px] px-2 py-0.5 rounded-md bg-slate-800/80 text-slate-400">#${escapeHtml(tag)}</span>`).join('')}
          </div>
        ` : ''}
      </div>

      <!-- Card Footer -->
      <div class="flex items-center justify-between text-[11px] text-slate-500 pt-3 mt-3 border-t border-slate-800/80">
        <span class="flex items-center gap-1">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
          ${escapeHtml(snippet.author_name || 'Anonymous')}
        </span>
        <span>${formatDate(snippet.created_at)}</span>
      </div>
    `;

    container.appendChild(card);
  });

  // Re-run Prism highlighting
  if (window.Prism) {
    Prism.highlightAll();
  }
}

async function handleSaveSnippet(e) {
  e.preventDefault();
  if (!currentToken) {
    openAuthModal('login');
    return;
  }

  const editId = document.getElementById('snippet-edit-id').value;
  const title = document.getElementById('snippet-title').value.trim();
  const language = document.getElementById('snippet-language').value;
  const status = document.getElementById('snippet-status').value;
  const code = document.getElementById('snippet-code').value;
  const description = document.getElementById('snippet-description').value.trim();
  const tags = document.getElementById('snippet-tags').value.trim();

  const payload = { title, language, status, code, description, tags };
  const method = editId ? 'PUT' : 'POST';
  const url = editId ? `/api/snippets/${editId}` : '/api/snippets';

  try {
    const res = await fetch(url, {
      method,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${currentToken}`
      },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (data.success) {
      closeModal('modal-snippet');
      showToast(editId ? 'Đã cập nhật snippet thành công!' : 'Tạo snippet mới thành công!', 'success');
      loadStats();
      loadSnippets();
    } else {
      showToast(data.error || 'Không thể lưu snippet', 'error');
    }
  } catch (err) {
    showToast('Lỗi lưu snippet: ' + err.message, 'error');
  }
}

function editSnippet(id) {
  const snippet = cachedSnippets.find(s => s.id === id);
  if (!snippet) return;

  document.getElementById('snippet-modal-title').textContent = 'Chỉnh sửa Code Snippet';
  document.getElementById('snippet-edit-id').value = snippet.id;
  document.getElementById('snippet-title').value = snippet.title;
  document.getElementById('snippet-language').value = snippet.language;
  document.getElementById('snippet-status').value = snippet.status;
  document.getElementById('snippet-code').value = snippet.code;
  document.getElementById('snippet-description').value = snippet.description || '';
  document.getElementById('snippet-tags').value = snippet.tags || '';

  openModal('modal-snippet');
}

async function deleteSnippet(id) {
  if (!confirm(`Bạn có chắc chắn muốn xóa snippet ID #${id} không?`)) return;

  try {
    const res = await fetch(`/api/snippets/${id}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${currentToken}` }
    });
    const data = await res.json();
    if (data.success) {
      showToast(data.message, 'success');
      loadStats();
      loadSnippets();
    } else {
      showToast(data.error || 'Không thể xóa snippet', 'error');
    }
  } catch (err) {
    showToast('Lỗi khi xóa snippet: ' + err.message, 'error');
  }
}

function copySnippetCode(id) {
  const snippet = cachedSnippets.find(s => s.id === id);
  if (!snippet) return;
  navigator.clipboard.writeText(snippet.code).then(() => {
    showToast('Đã copy mã nguồn vào clipboard!', 'success');
  }).catch(() => {
    showToast('Không thể tự động copy', 'error');
  });
}

// Stats & Observability
async function loadStats() {
  try {
    const headers = {};
    if (currentToken) headers['Authorization'] = `Bearer ${currentToken}`;
    const res = await fetch('/api/snippets/meta/summary', { headers });
    const data = await res.json();
    if (data.success) {
      document.getElementById('stat-total').textContent = data.stats.totalSnippets;
      document.getElementById('stat-public').textContent = data.stats.publicSnippets;
      document.getElementById('stat-private').textContent = data.stats.privateSnippets;
    }
  } catch (err) {
    console.error('Stats error:', err);
  }
}

async function checkSystemHealth() {
  try {
    const res = await fetch('/health');
    const data = await res.json();
    if (data.status === 'UP') {
      document.getElementById('top-status-text').textContent = 'UP (Cloud Live)';
    } else {
      document.getElementById('top-status-text').textContent = 'DEGRADED';
    }
  } catch {
    document.getElementById('top-status-text').textContent = 'OFFLINE';
  }
}

async function refreshHealthModal() {
  document.getElementById('hm-status').textContent = 'Đang tải...';
  try {
    const [healthRes, metricsRes] = await Promise.all([
      fetch('/health'),
      fetch('/metrics')
    ]);
    const health = await healthRes.json();
    const metrics = await metricsRes.json();

    document.getElementById('hm-status').textContent = `${health.status} (${health.service} v${health.version})`;
    document.getElementById('hm-db').textContent = `${health.database.status} (${health.database.type} - Độ trễ: ${health.database.latencyMs}ms)`;
    document.getElementById('hm-uptime').textContent = `${health.uptimeSeconds} giây (${(health.uptimeSeconds / 60).toFixed(1)} phút)`;
    document.getElementById('hm-ram').textContent = `${metrics.metrics.memory.rssMb} MB RSS / ${metrics.metrics.memory.heapUsedMb} MB Heap`;
    document.getElementById('hm-requests').textContent = `${metrics.metrics.totalRequests} reqs (2xx: ${metrics.metrics.statusCodes['2xx']}, 4xx: ${metrics.metrics.statusCodes['4xx']}, 5xx: ${metrics.metrics.statusCodes['5xx']})`;
  } catch (err) {
    showToast('Lỗi tải observability metrics: ' + err.message, 'error');
  }
}

function openHealthModal() {
  openModal('modal-health');
  refreshHealthModal();
}

// UI Filters & Modals
function setStatusFilter(status) {
  if (status === 'my' && !currentUser) {
    openAuthModal('login');
    showToast('Vui lòng đăng nhập để xem snippet của bạn', 'info');
    return;
  }

  currentFilter.status = status;
  ['all', 'public', 'private', 'my'].forEach(s => {
    const btn = document.getElementById(`btn-status-${s}`);
    if (s === status) {
      btn.className = 'px-3 py-1.5 rounded-lg text-xs font-semibold bg-emerald-500 text-slate-950 transition';
    } else {
      btn.className = 'px-3 py-1.5 rounded-lg text-xs font-medium text-slate-400 hover:text-white transition';
    }
  });
  loadSnippets();
}

function resetFilters() {
  currentFilter.status = 'all';
  currentFilter.language = 'all';
  currentFilter.search = '';
  document.getElementById('search-input').value = '';
  document.getElementById('filter-language').value = 'all';
  setStatusFilter('all');
}

function openModal(id) {
  document.getElementById(id).classList.remove('hidden');
}

function closeModal(id) {
  document.getElementById(id).classList.add('hidden');
}

function openSnippetModal() {
  if (!currentUser) {
    openAuthModal('login');
    showToast('Vui lòng đăng nhập để tạo code snippet mới', 'info');
    return;
  }
  document.getElementById('snippet-modal-title').textContent = 'Thêm Code Snippet Mới';
  document.getElementById('snippet-edit-id').value = '';
  document.getElementById('form-snippet').reset();
  openModal('modal-snippet');
}

function openAuthModal(tab = 'login') {
  openModal('modal-auth');
  switchAuthTab(tab);
}

function switchAuthTab(tab) {
  const tabLogin = document.getElementById('tab-login');
  const tabReg = document.getElementById('tab-register');
  const formLogin = document.getElementById('form-login');
  const formReg = document.getElementById('form-register');

  if (tab === 'login') {
    tabLogin.className = 'flex-1 pb-3 font-semibold text-sm text-emerald-400 border-b-2 border-emerald-500 transition';
    tabReg.className = 'flex-1 pb-3 font-semibold text-sm text-slate-400 hover:text-white transition';
    formLogin.classList.remove('hidden');
    formReg.classList.add('hidden');
  } else {
    tabReg.className = 'flex-1 pb-3 font-semibold text-sm text-emerald-400 border-b-2 border-emerald-500 transition';
    tabLogin.className = 'flex-1 pb-3 font-semibold text-sm text-slate-400 hover:text-white transition';
    formReg.classList.remove('hidden');
    formLogin.classList.add('hidden');
  }
}

function showToast(message, type = 'info') {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.className = 'fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl shadow-2xl text-sm font-medium transition duration-300 transform translate-y-0 ';

  if (type === 'success') {
    toast.className += 'bg-emerald-600 text-white';
  } else if (type === 'error') {
    toast.className += 'bg-red-600 text-white';
  } else {
    toast.className += 'bg-slate-800 text-white border border-slate-700';
  }

  toast.classList.remove('hidden');
  setTimeout(() => {
    toast.classList.add('hidden');
  }, 3500);
}

// Helpers
function escapeHtml(str) {
  if (!str) return '';
  return str.replace(/[&<>"']/g, m => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  })[m]);
}

function formatDate(isoStr) {
  if (!isoStr) return '';
  const d = new Date(isoStr);
  return d.toLocaleDateString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}
