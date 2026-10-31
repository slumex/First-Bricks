"use strict";
document.querySelectorAll("form[data-bsx-upload]").forEach((form) => {
  const input = form.querySelector('input[type="file"]');
  const error = form.querySelector("[data-upload-error]");
  const validate = () => {
    const file = input.files[0];
    const message = file && file.size > Number(input.dataset.maxBytes)
      ? `Ce fichier est trop volumineux. La limite est de ${input.dataset.maxLabel}.`
      : "";
    input.setCustomValidity(message);
    error.textContent = message;
    error.hidden = !message;
    return !message;
  };
  input.addEventListener("change", validate);
  form.addEventListener("submit", (event) => {
    if (!validate()) {
      event.preventDefault();
      input.reportValidity();
      return;
    }
    const button = form.querySelector("button");
    button.disabled = true;
    button.textContent = "Importation en cours…";
  });
});
