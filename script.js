const products = [
  {id:1,name:"Lava Phone",price:9999,image:"Screenshot_20260824-183540_Google.jpg"},
  {id:2,name:"Biometric",price:1499,image:"Screenshot_20260824-183612_Google.jpg"},
  {id:3,name:"T-Shirt",price:499,image:"Screenshot_20260824-183701.jpg"},
  {id:4,name:"Bottle",price:299,image:"Screenshot_20260824-183743.jpg"},
  {id:5,name:"Dairy Product",price:199,image:"Screenshot_20260824-183844_Google.jpg"}
];

let cart = JSON.parse(localStorage.getItem("preeshoCart") || "[]");

function renderProducts() {
  document.getElementById("products").innerHTML = products.map(p => `
    <div class="product">
      <img src="${p.image}" style="width:100%;height:180px;object-fit:contain;border-radius:8px;">
      <h3>${p.name}</h3>
      <div>₹${p.price}</div>
      <button onclick="addToCart(${p.id})">Add to Cart</button>
    </div>
  `).join("");
}

function addToCart(id) {
  const item = cart.find(x => x.id === id);

  if (item) {
    item.qty++;
  } else {
    cart.push({id, qty:1});
  }

  save();
  renderCart();
}

function changeQty(id, delta) {
  const item = cart.find(x => x.id === id);
  if (!item) return;

  item.qty += delta;

  if (item.qty <= 0) {
    cart = cart.filter(x => x.id !== id);
  }

  save();
  renderCart();
}

function renderCart() {
  const box = document.getElementById("cartItems");

  let total = 0;
  let count = 0;

  if (!cart.length) {
    box.innerHTML = "<p>Your cart is empty.</p>";
  } else {
    box.innerHTML = cart.map(item => {
      const p = products.find(x => x.id === item.id);

      total += p.price * item.qty;
      count += item.qty;

      return `
        <div>
          <b>${p.name}</b> × ${item.qty}
          <br>
          ₹${p.price * item.qty}
          <br>
          <button onclick="changeQty(${p.id},1)">+</button>
          <button onclick="changeQty(${p.id},-1)">−</button>
        </div>
        <hr>
      `;
    }).join("");
  }

  document.getElementById("cartTotal").textContent = total;
  document.getElementById("cartCount").textContent = count;
}

function save() {
  localStorage.setItem("preeshoCart", JSON.stringify(cart));
}

function placeOrder() {
  if (!cart.length) {
    alert("Cart is empty");
    return;
  }

  const name = document.getElementById("customerName").value.trim();
  const mobile = document.getElementById("customerMobile").value.trim();
  const address = document.getElementById("customerAddress").value.trim();

  if (!name || !mobile || !address) {
    alert("Please fill Name, Mobile and Address");
    return;
  }

  let total = 0;

  const lines = cart.map(item => {
    const p = products.find(x => x.id === item.id);
    total += p.price * item.qty;
    return `${p.name} x ${item.qty} = ₹${p.price * item.qty}`;
  });

  const message =
    `New Preesho Order\n\n` +
    `Name: ${name}\n` +
    `Mobile: ${mobile}\n` +
    `Address: ${address}\n\n` +
    `${lines.join("\n")}\n\n` +
    `Total: ₹${total}`;

  const whatsappNumber = "91XXXXXXXXXX";

  window.open(
    `https://wa.me/${whatsappNumber}?text=${encodeURIComponent(message)}`,
    "_blank"
  );
}

document.getElementById("cartBtn").onclick = () => {
  document.getElementById("cartSection").classList.toggle("hidden");
};

renderProducts();
renderCart();
