const state = { products: [], cart: JSON.parse(localStorage.getItem("vendah-cart") || "[]"), filters: { q: "", category: "", sort: "relevance", min_price: "", max_price: "" }, user: null };
const $ = (selector) => document.querySelector(selector);
const money = (value) => new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(value);
const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" }[char]));

async function api(path, options = {}) {
  const response = await fetch(path, { headers: { "Content-Type": "application/json", ...(options.headers || {}) }, ...options });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || "Não foi possível concluir.");
  return data;
}

async function loadCategories() {
  const categories = await api("/api/categories");
  $("#all-count").textContent = "";
  $("#category-filters").innerHTML = categories.map((category) => `<label><input type="radio" name="category" value="${escapeHtml(category.slug)}"> ${escapeHtml(category.name)} <span>${category.product_count}</span></label>`).join("");
  document.querySelectorAll("input[name=category]").forEach((input) => input.addEventListener("change", () => { state.filters.category = input.value; loadProducts(); }));
}

function productCard(product) {
  const oldPrice = product.old_price ? `<p class="old-price">${money(product.old_price)}</p>` : "";
  return `<article class="product-card" data-id="${product.id}">
    <div class="product-image"><img src="${escapeHtml(product.image_url)}" alt="${escapeHtml(product.title)}" loading="lazy" onerror="this.style.display='none'">${product.badge ? `<span class="badge">${escapeHtml(product.badge)}</span>` : ""}<button class="heart" aria-label="Favoritar">♡</button></div>
    <div class="card-info"><p class="card-category">${escapeHtml(product.category)}</p><h3>${escapeHtml(product.title)}</h3><p class="price">${money(product.price)}</p>${oldPrice}<p class="installments">em até 10x sem juros</p><p class="location">⌖ ${escapeHtml(product.location)} · ${escapeHtml(product.shipping)}</p></div>
  </article>`;
}

async function loadProducts() {
  const grid = $("#product-grid");
  grid.innerHTML = '<div class="loading"><span></span><span></span><span></span><p>Encontrando os melhores produtos...</p></div>';
  const query = new URLSearchParams(Object.entries(state.filters).filter(([, value]) => value));
  try {
    const data = await api(`/api/products?${query}`);
    state.products = data.products;
    $("#result-total").textContent = `(${data.pagination.total})`;
    $("#results-title").firstChild.textContent = state.filters.q ? `Resultados para "${state.filters.q}" ` : state.filters.category ? `${data.products[0]?.category || "Categoria"} ` : "Ofertas em destaque ";
    $("#empty-state").hidden = data.products.length > 0;
    grid.hidden = data.products.length === 0;
    grid.innerHTML = data.products.map(productCard).join("");
    renderActiveFilters();
    document.querySelectorAll(".product-card").forEach((card) => card.addEventListener("click", (event) => { if (!event.target.closest(".heart")) openProduct(card.dataset.id); }));
    document.querySelectorAll(".heart").forEach((button) => button.addEventListener("click", (event) => { event.stopPropagation(); button.textContent = button.textContent === "♡" ? "♥" : "♡"; }));
  } catch (error) { grid.innerHTML = `<div class="empty-state"><h3>${escapeHtml(error.message)}</h3></div>`; }
}

function renderActiveFilters() {
  const chips = [];
  if (state.filters.q) chips.push(`<span class="filter-chip">Busca: ${escapeHtml(state.filters.q)} <button data-clear="q">×</button></span>`);
  if (state.filters.category) chips.push(`<span class="filter-chip">${escapeHtml(state.filters.category)} <button data-clear="category">×</button></span>`);
  $("#active-filters").innerHTML = chips.join("");
  document.querySelectorAll("[data-clear]").forEach((button) => button.addEventListener("click", () => { state.filters[button.dataset.clear] = ""; if (button.dataset.clear === "category") document.querySelector('input[name=category][value=""]').checked = true; loadProducts(); }));
}

async function openProduct(id) {
  try {
    const { product } = await api(`/api/products/${id}`);
    $("#product-detail").innerHTML = `<div class="detail-layout"><img class="detail-image" src="${escapeHtml(product.image_url)}" alt="${escapeHtml(product.title)}"><div class="detail-content"><p class="card-category">${escapeHtml(product.category)} · ${escapeHtml(product.condition)}</p><h2>${escapeHtml(product.title)}</h2><p>${escapeHtml(product.description)}</p><div class="detail-price"><p class="price">${money(product.price)}</p><p class="installments">em até 10x sem juros</p><p class="stock">${product.stock} unidades disponíveis · ${escapeHtml(product.shipping)}</p></div><div class="detail-actions"><button class="primary-button" id="add-detail">Adicionar ao carrinho <span>→</span></button></div></div></div>`;
    $("#product-modal").hidden = false;
    $("#add-detail").addEventListener("click", () => { addToCart(product); closeModals(); });
  } catch (error) { toast(error.message); }
}

function addToCart(product) {
  const existing = state.cart.find((item) => item.id === product.id);
  if (existing) existing.quantity += 1; else state.cart.push({ id: product.id, title: product.title, price: product.price, image_url: product.image_url, quantity: 1 });
  localStorage.setItem("vendah-cart", JSON.stringify(state.cart)); updateCart(); toast("Produto adicionado ao carrinho.");
}
function updateCart() { $("#cart-count").textContent = state.cart.reduce((sum, item) => sum + item.quantity, 0); $("#cart-modal-count").textContent = `(${state.cart.length})`; }
function renderCart() {
  const items = $("#cart-items");
  if (!state.cart.length) { items.innerHTML = '<div class="cart-empty">Seu carrinho está esperando por você.<br>Adicione um produto para começar.</div>'; $("#cart-total").textContent = money(0); return; }
  items.innerHTML = state.cart.map((item, index) => `<div class="cart-line"><img src="${escapeHtml(item.image_url)}" alt=""><h3>${escapeHtml(item.title)}<small>Quantidade: ${item.quantity}</small></h3><strong>${money(item.price * item.quantity)}</strong><button class="remove-line" data-remove="${index}">×</button></div>`).join("");
  $("#cart-total").textContent = money(state.cart.reduce((sum, item) => sum + item.price * item.quantity, 0));
  document.querySelectorAll("[data-remove]").forEach((button) => button.addEventListener("click", () => { state.cart.splice(Number(button.dataset.remove), 1); localStorage.setItem("vendah-cart", JSON.stringify(state.cart)); updateCart(); renderCart(); }));
}

function showLogin() { $("#login-modal").hidden = false; $("#login-user").focus(); }
function closeModals() { document.querySelectorAll(".modal-backdrop").forEach((modal) => { modal.hidden = true; }); }
function toast(message) { const element = $("#toast"); element.textContent = message; element.classList.add("show"); setTimeout(() => element.classList.remove("show"), 2800); }
function resetFilters() { state.filters = { q: "", category: "", sort: "relevance", min_price: "", max_price: "" }; $("#search").value = ""; $("#min-price").value = ""; $("#max-price").value = ""; document.querySelector('input[name=category][value=""]').checked = true; $("#sort").value = "relevance"; loadProducts(); }

$("#search-button").addEventListener("click", () => { state.filters.q = $("#search").value.trim(); loadProducts(); });
$("#search").addEventListener("keydown", (event) => { if (event.key === "Enter") $("#search-button").click(); });
$("#sort").addEventListener("change", (event) => { state.filters.sort = event.target.value; loadProducts(); });
$("#apply-price").addEventListener("click", () => { state.filters.min_price = $("#min-price").value; state.filters.max_price = $("#max-price").value; loadProducts(); });
$("#clear-filters").addEventListener("click", resetFilters); $("#empty-clear").addEventListener("click", resetFilters);
document.querySelectorAll("[data-category]").forEach((button) => button.addEventListener("click", () => { state.filters.category = button.dataset.category; const radio = document.querySelector(`input[name=category][value="${button.dataset.category}"]`); if (radio) radio.checked = true; loadProducts(); $("#catalog").scrollIntoView({ behavior: "smooth" }); }));
$("#hero-explore").addEventListener("click", () => $("#catalog").scrollIntoView({ behavior: "smooth" }));
$("#account-button").addEventListener("click", () => state.user ? toast(`Olá, ${state.user.username}!`) : showLogin());
$("#cart-button").addEventListener("click", () => { renderCart(); $("#cart-modal").hidden = false; });
$("#checkout-button").addEventListener("click", async () => { if (!state.cart.length) return toast("Seu carrinho está vazio."); if (!state.user) { closeModals(); showLogin(); return; } try { await api("/api/orders", { method: "POST", body: JSON.stringify({ items: state.cart.map((item) => ({ product_id: item.id, quantity: item.quantity })) }) }); state.cart = []; localStorage.removeItem("vendah-cart"); updateCart(); renderCart(); toast("Pedido criado com sucesso!"); } catch (error) { toast(error.message); } });
$("#sell-button").addEventListener("click", () => state.user ? toast("Em breve: painel para publicar seus produtos.") : showLogin());
$("#login-form").addEventListener("submit", async (event) => { event.preventDefault(); $("#login-message").textContent = ""; try { const data = await api("/api/auth/login", { method: "POST", body: JSON.stringify({ login: $("#login-user").value, password: $("#login-password").value }) }); state.user = data.user; $("#account-kicker").textContent = `Olá, ${state.user.username}`; $("#account-label").textContent = "Minha conta"; closeModals(); toast("Login realizado. Boas compras!"); } catch (error) { $("#login-message").textContent = error.message; } });
document.querySelectorAll(".close-modal").forEach((button) => button.addEventListener("click", closeModals));
document.querySelectorAll(".modal-backdrop").forEach((modal) => modal.addEventListener("click", (event) => { if (event.target === modal) closeModals(); }));

updateCart();
Promise.all([loadCategories(), loadProducts()]).catch((error) => toast(error.message));