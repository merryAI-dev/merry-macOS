const fileInput = document.querySelector("#fileInput");
const openButton = document.querySelector("#openButton");
const heroOpenButton = document.querySelector("#heroOpenButton");
const statusButton = document.querySelector("#statusButton");
const customDuplex = document.querySelector("#customDuplex");
const customColorMode = document.querySelector("#customColorMode");
const customNumberUp = document.querySelector("#customNumberUp");
const customPrintButton = document.querySelector("#customPrintButton");
const wizardOverlay = document.querySelector("#wizardOverlay");
const wizardFileName = document.querySelector("#wizardFileName");
const wizardFileMeta = document.querySelector("#wizardFileMeta");
const wizardDuplex = document.querySelector("#wizardDuplex");
const wizardColorMode = document.querySelector("#wizardColorMode");
const wizardNumberUp = document.querySelector("#wizardNumberUp");
const wizardQueueButton = document.querySelector("#wizardQueueButton");
const wizardQueueStatus = document.querySelector("#wizardQueueStatus");
const wizardCancelButton = document.querySelector("#wizardCancelButton");
const wizardConfirmButton = document.querySelector("#wizardConfirmButton");
const dropzone = document.querySelector("#dropzone");
const statusText = document.querySelector("#statusText");
const selectedFileName = document.querySelector("#selectedFileName");
const selectedFileMeta = document.querySelector("#selectedFileMeta");
const emptyState = document.querySelector("#emptyState");
const previewState = document.querySelector("#previewState");
const pdfFrame = document.querySelector("#pdfFrame");

let currentFile = null;
let currentObjectURL = null;
let currentWizardConfig = null;

openButton.addEventListener("click", () => fileInput.click());
heroOpenButton.addEventListener("click", () => fileInput.click());
statusButton.addEventListener("click", loadQueueStatus);
customPrintButton.addEventListener("click", () => {
  openCustomPrintWizard({
    duplex: customDuplex.value,
    colorMode: customColorMode.value,
    numberUp: customNumberUp.value,
  });
});
wizardQueueButton.addEventListener("click", async () => {
  wizardQueueStatus.textContent = "큐 상태를 확인하는 중입니다...";
  try {
    const message = await fetchQueueStatus();
    wizardQueueStatus.textContent = message;
  } catch (error) {
    wizardQueueStatus.textContent = normalizeError(error);
  }
});
wizardCancelButton.addEventListener("click", closeWizard);
wizardConfirmButton.addEventListener("click", async () => {
  if (!currentWizardConfig) {
    closeWizard();
    return;
  }
  const confirmedConfig = currentWizardConfig;
  closeWizard();
  await printCurrentFile(confirmedConfig);
});
wizardOverlay.addEventListener("click", (event) => {
  if (event.target === wizardOverlay) {
    closeWizard();
  }
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !wizardOverlay.classList.contains("hidden")) {
    closeWizard();
  }
});
fileInput.addEventListener("change", (event) => {
  const [file] = event.target.files ?? [];
  if (file) {
    setSelectedFile(file);
  }
});

for (const eventName of ["dragenter", "dragover"]) {
  dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    dropzone.classList.add("dropzone-target");
  });
}

for (const eventName of ["dragleave", "drop"]) {
  dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    dropzone.classList.remove("dropzone-target");
  });
}

dropzone.addEventListener("drop", (event) => {
  const [file] = [...(event.dataTransfer?.files ?? [])];
  if (!file) {
    return;
  }
  if (!isPDF(file)) {
    setStatus("PDF 파일만 드롭할 수 있습니다.", true);
    return;
  }
  setSelectedFile(file);
});

async function loadQueueStatus() {
  setStatus("큐 상태를 확인하는 중입니다...");
  try {
    const message = await fetchQueueStatus();
    setStatus(message);
  } catch (error) {
    setStatus(normalizeError(error), true);
  }
}

async function fetchQueueStatus() {
  const response = await fetch("/api/status");
  const payload = await response.json();
  if (!response.ok || !payload.ok) {
    throw new Error(payload.error || "큐 상태 확인에 실패했습니다.");
  }
  return payload.output || "큐 상태를 확인했습니다.";
}

async function printCurrentFile(config) {
  if (!currentFile) {
    setStatus("먼저 PDF를 선택하세요.", true);
    return;
  }
  if (!config) {
    setStatus("인쇄 설정을 다시 선택하세요.", true);
    return;
  }

  disablePrintButtons(true);
  setStatus("인쇄 요청을 보내는 중입니다...");

  try {
    const formData = new FormData();
    formData.append("file", currentFile, currentFile.name);
    if (config.preset) {
      formData.append("preset", config.preset);
    } else {
      formData.append("duplex", config.duplex || "long-edge");
      formData.append("colorMode", config.colorMode || "color");
      formData.append("numberUp", config.numberUp || "1");
    }

    const response = await fetch("/api/print", {
      method: "POST",
      body: formData,
    });

    const payload = await response.json();
    if (!response.ok || !payload.ok) {
      throw new Error(payload.error || "인쇄 요청에 실패했습니다.");
    }

    setStatus(payload.output || "인쇄 요청을 보냈습니다.");
  } catch (error) {
    setStatus(normalizeError(error), true);
  } finally {
    disablePrintButtons(false);
  }
}

function openCustomPrintWizard(config) {
  if (!currentFile) {
    setStatus("먼저 PDF를 선택하세요.", true);
    return;
  }

  currentWizardConfig = config;
  wizardFileName.textContent = currentFile.name;
  wizardFileMeta.textContent = formatFileMeta(currentFile);
  wizardDuplex.textContent = formatDuplex(config.duplex || "long-edge");
  wizardColorMode.textContent = formatColorMode(config.colorMode || "color");
  wizardNumberUp.textContent = formatNumberUp(config.numberUp || "1");
  wizardQueueStatus.textContent = "아직 조회하지 않았습니다.";
  wizardOverlay.classList.remove("hidden");
  wizardOverlay.classList.add("flex");
}

function closeWizard() {
  currentWizardConfig = null;
  wizardOverlay.classList.add("hidden");
  wizardOverlay.classList.remove("flex");
}

function setSelectedFile(file) {
  if (!isPDF(file)) {
    setStatus("PDF 파일만 열 수 있습니다.", true);
    return;
  }

  currentFile = file;
  selectedFileName.textContent = file.name;
  selectedFileMeta.textContent = formatFileMeta(file);

  if (currentObjectURL) {
    URL.revokeObjectURL(currentObjectURL);
  }
  currentObjectURL = URL.createObjectURL(file);
  pdfFrame.src = currentObjectURL;

  emptyState.classList.add("hidden");
  previewState.classList.remove("hidden");
  setStatus(`${file.name}을 열었습니다.`);
}

function disablePrintButtons(disabled) {
  customPrintButton.disabled = disabled;
  wizardConfirmButton.disabled = disabled;
  wizardQueueButton.disabled = disabled;
  wizardCancelButton.disabled = disabled;
}

function setStatus(message, isError = false) {
  statusText.textContent = message;
  statusText.classList.toggle("text-red-600", isError);
  statusText.classList.toggle("text-slate-700", !isError);
}

function isPDF(file) {
  return file.type === "application/pdf" || file.name.toLowerCase().endsWith(".pdf");
}

function formatFileMeta(file) {
  const mb = (file.size / (1024 * 1024)).toFixed(2);
  return `${mb} MB`;
}

function formatDuplex(value) {
  if (value === "one-sided") {
    return "단면";
  }
  if (value === "short-edge") {
    return "양면 짧은쪽 넘김";
  }
  return "양면";
}

function formatColorMode(value) {
  return value === "mono" ? "흑백" : "컬러";
}

function formatNumberUp(value) {
  return value === "2" ? "한 장에 두 페이지" : "한 장에 한 페이지";
}

function normalizeError(error) {
  if (error instanceof Error) {
    return error.message || "오류가 발생했습니다.";
  }
  return "오류가 발생했습니다.";
}
