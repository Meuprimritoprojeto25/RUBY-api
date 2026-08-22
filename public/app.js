document.addEventListener("DOMContentLoaded", () => {
  const toggle = document.querySelector("[data-menu-toggle]");
  const navigation = document.querySelector("[data-navigation]");
  if (toggle && navigation) {
    toggle.addEventListener("click", () => navigation.classList.toggle("open"));
  }

  const countdown = document.querySelector("[data-countdown]");
  if (countdown) {
    let seconds = 2 * 60 * 60 + 14 * 60 + 38;
    window.setInterval(() => {
      seconds = Math.max(0, seconds - 1);
      const hours = String(Math.floor(seconds / 3600)).padStart(2, "0");
      const minutes = String(Math.floor((seconds % 3600) / 60)).padStart(2, "0");
      const rest = String(seconds % 60).padStart(2, "0");
      countdown.textContent = `${hours}:${minutes}:${rest}`;
    }, 1000);
  }
});