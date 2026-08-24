const products = [
  {id:1,name:"Product 1",price:99,emoji:"🛍️"},
  {id:2,name:"Product 2",price:149,emoji:"🎁"},
  {id:3,name:"Product 3",price:199,emoji:"👕"},
  {id:4,name:"Product 4",price:249,emoji:"⌚"}
];

let cart = JSON.parse(localStorage.getItem("preeshoCart") || "[]");

function renderProducts(){
  document.getElementById("products").innerHTML = products.map(p => `
    <div class="card">
      <div class="photo">${p.emoji}</div>
      <h3>${p.name}</h3>
      <div class="price">₹${p.price}</div>
      <button onclick="addToCart(${p.id})">Add to Cart</button>
    </div>`).join("");
}

function addToCart(id){
  const item = cart.find(x=>x.id===id);
  if(item) item.qty++;
  else cart.push({id,qty:1});
  save();
  renderCart();
}

function changeQty(id,delta){
  const item=cart.find(x=>x.id===id);
  if(!item) return;
  item.qty += delta;
  if(item.qty<=0) cart=cart.filter(x=>x.id!==id);
  save();
  renderCart();
}

function renderCart(){
  const box=document.getElementById("cartItems");
  let total=0, count=0;
  box.innerHTML=cart.length ? cart.map(item=>{
    const p=products.find(x=>x.id===item.id);
    total += p.price*item.qty; count += item.qty;
    return `<div class="cart-row"><span>${p.name} × ${item.qty}</span><span>₹${p.price*item.qty}<br><button onclick="changeQty(${p.id},1)">+</button> <button onclick="changeQty(${p.id},-1)">−</button></span></div>`;
  }).join("") : "<p>Your cart is empty.</p>";
  document.getElementById("cartTotal").textContent=total;
  document.getElementById("cartCount").textContent=count;
}

function save(){localStorage.setItem("preeshoCart",JSON.stringify(cart));}

function placeOrder(){
  if(!cart.length){alert("Cart is empty");return;}
  const name=document.getElementById("customerName").value.trim();
  const mobile=document.getElementById("customerMobile").value.trim();
  const address=document.getElementById("customerAddress").value.trim();
  if(!name||!mobile||!address){alert("Please fill Name, Mobile and Address");return;}
  let total=0;
  const lines=cart.map(item=>{
    const p=products.find(x=>x.id===item.id);
    total+=p.price*item.qty;
    return `${p.name} x ${item.qty} = ₹${p.price*item.qty}`;
  });
  const message=`New Preesho Order%0A%0AName: ${encodeURIComponent(name)}%0AMobile: ${encodeURIComponent(mobile)}%0AAddress: ${encodeURIComponent(address)}%0A%0A${encodeURIComponent(lines.join("\n"))}%0A%0ATotal: ₹${total}`;
  const whatsappNumber="91XXXXXXXXXX"; // Replace with your WhatsApp number
  window.open(`https://wa.me/${whatsappNumber}?text=${message}`,"_blank");
}

document.getElementById("cartBtn").onclick=()=>document.getElementById("cartSection").classList.toggle("hidden");
renderProducts();
renderCart();
