// Adds a copy-to-clipboard button to every code block. Progressive
// enhancement: without JS (or the clipboard API) there is no button.
if (navigator.clipboard) {
  document.querySelectorAll("pre").forEach((pre) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "copy-btn";
    button.textContent = "Copy";
    button.addEventListener("click", () => {
      const code = pre.querySelector("code") || pre;
      navigator.clipboard.writeText(code.innerText).then(() => {
        button.textContent = "Copied!";
        setTimeout(() => {
          button.textContent = "Copy";
        }, 2000);
      });
    });
    pre.appendChild(button);
  });
}
