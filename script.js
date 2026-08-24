const products = [
  {
    id: 1,
    name: "Lava Phone",
    price: 9999,
    category: "Phone",
    image: "Screenshot_20260824-183540_Google.jpg"
  },
  {
    id: 2,
    name: "Biometric",
    price: 1499,
    category: "Security",
    image: "Screenshot_20260824-183612_Google.jpg"
  },
  {
    id: 3,
    name: "T-Shirt",
    price: 499,
    category: "Fashion",
    image: "Screenshot_20260824-183701.jpg"
  },
  {
    id: 4,
    name: "Bottle",
    price: 299,
    category: "Bottle",
    image: "Screenshot_20260824-183743.jpg"
  },
  {
    id: 5,
    name: "Dairy Product",
    price: 199,
    category: "Dairy",
    image: "Screenshot_20260824-183844_Google.jpg"
  }
];

let cart = JSON.parse(
  localStorage.getItem("preeshoCart") || "[]"
);

let selectedCategory = "All";

function renderProducts(list = products) {

  const box = document.getElementById("products");

  if (list.length === 0) {
    box.innerHTML = "<p>No product found.</p>";
    return;
  }

  box.innerHTML = list.map(function(p) {

    return `
      <div class="product">

        <img
          src="${p.image}"
          alt="${p.name}"
          style="width:100%;height:180px;object-fit:contain;border-radius:8px;"
        >

        <h3>${p.name}</h3>

        <p>${p.category}</p>

        <div style="font-size:20px;font-weight:bold;">
          ₹${p.price}
        </div>

        <button onclick="addToCart(${p.id})">
          🛒 Add to Cart
        </button>

        <button
          onclick="buyNow(${p.id})"
          style="margin-top:8px;background:#ff4f81;color:white;border:0;padding:10px;width:100%;border-radius:7px;"
        >
          ⚡ Buy Now
        </button>

      </div>
    `;

  }).join("");
}


function searchProducts() {

  const text = document
    .getElementById("searchBox")
    .value
    .toLowerCase()
    .trim();

  filterProducts(text, selectedCategory);
}


function selectCategory(category) {

  selectedCategory = category;

  const text = document
    .getElementById("searchBox")
    .value
    .toLowerCase()
    .trim();

  filterProducts(text, category);
}


function filterProducts(text, category) {

  const filtered = products.filter(function(p) {

    const matchesSearch =
      p.name.toLowerCase().includes(text);

    const matchesCategory =
      category === "All" ||
      p.category === category;

    return matchesSearch && matchesCategory;

  });

  renderProducts(filtered);
}


function addToCart(id) {

  const item = cart.find(function(x) {
    return x.id === id;
  });

  if (item) {

    item.qty++;

  } else {

    cart.push({
      id: id,
      qty: 1
    });

  }

  save();
  renderCart();
}


function buyNow(id) {

  addToCart(id);

  document
    .getElementById("cartSection")
    .classList
    .remove("hidden");

  window.scrollTo({
    top: document.body.scrollHeight,
    behavior: "smooth"
  });

}


function changeQty(id, delta) {

  const item = cart.find(function(x) {
    return x.id === id;
  });

  if (!item) return;

  item.qty += delta;

  if (item.qty <= 0) {

    cart = cart.filter(function(x) {
      return x.id !== id;
    });

  }

  save();
  renderCart();
}


function renderCart() {

  const box =
    document.getElementById("cartItems");

  let total = 0;
  let count = 0;

  if (cart.length === 0) {

    box.innerHTML =
      "<p>Your cart is empty.</p>";

  } else {

    box.innerHTML = cart.map(function(item) {

      const p = products.find(function(x) {
        return x.id === item.id;
      });

      if (!p) return "";

      total += p.price * item.qty;
      count += item.qty;

      return `
        <div>

          <b>${p.name}</b> × ${item.qty}

          <br>

          ₹${p.price * item.qty}

          <br>

          <button onclick="changeQty(${p.id}, 1)">
            +
          </button>

          <button onclick="changeQty(${p.id}, -1)">
            −
          </button>

        </div>

        <hr>
      `;

    }).join("");

  }

  document.getElementById("cartTotal")
    .textContent = total;

  document.getElementById("cartCount")
    .textContent = count;

}


function save() {

  localStorage.setItem(
    "preeshoCart",
    JSON.stringify(cart)
  );

}


function placeOrder() {

  if (cart.length === 0) {

    alert("Cart is empty");
    return;

  }

  const name =
    document
      .getElementById("customerName")
      .value
      .trim();

  const mobile =
    document
      .getElementById("customerMobile")
      .value
      .trim();

  const address =
    document
      .getElementById("customerAddress")
      .value
      .trim();

  if (!name || !mobile || !address) {

    alert(
      "Please fill Name, Mobile and Address"
    );

    return;

  }

  let total = 0;

  const lines = cart.map(function(item) {

    const p = products.find(function(x) {
      return x.id === item.id;
    });

    total += p.price * item.qty;

    return (
      p.name +
      " x " +
      item.qty +
      " = ₹" +
      (p.price * item.qty)
    );

  });

  const message =
    "New Preesho Order\n\n" +
    "Name: " + name + "\n" +
    "Mobile: " + mobile + "\n" +
    "Address: " + address + "\n\n" +
    lines.join("\n") +
    "\n\nTotal: ₹" +
    total;

  const whatsappNumber =
    "91XXXXXXXXXX";

  window.open(
    "https://wa.me/" +
    whatsappNumber +
    "?text=" +
    encodeURIComponent(message),
    "_blank"
  );

}


document
  .getElementById("cartBtn")
  .onclick = function() {

    document
      .getElementById("cartSection")
      .classList
      .toggle("hidden");

  };


document
  .getElementById("searchBox")
  .addEventListener(
    "input",
    searchProducts
  );


renderProducts();
renderCart();
