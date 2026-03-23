import express from "express";
import multer from "multer";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = Number(process.env.PORT || 4310);
const HARNESS_PATH = "/Users/boram/printer-harness/printer_harness.py";
const QUEUE_NAME = "_6l85k35m5_j80";
const PRESET_SOURCE = "global-vendor-default";

const app = express();
const upload = multer({
  dest: path.join(os.tmpdir(), "printer-launcher-web"),
  limits: { fileSize: 100 * 1024 * 1024 },
});

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

app.get("/api/health", (_req, res) => {
  res.json({
    ok: true,
    queueName: QUEUE_NAME,
    presetSource: PRESET_SOURCE,
    harnessPath: HARNESS_PATH,
  });
});

app.get("/api/status", async (_req, res) => {
  try {
    const output = await runHarness(["status", "--queue-name", QUEUE_NAME]);
    res.json({ ok: true, output: output || "큐 상태를 확인했습니다." });
  } catch (error) {
    const fallbackOutput = await readUserQueueFallback(QUEUE_NAME);
    if (fallbackOutput) {
      res.json({ ok: true, output: fallbackOutput });
      return;
    }

    res.status(500).json({
      ok: false,
      error: normalizeError(error),
    });
  }
});

app.post("/api/print", upload.single("file"), async (req, res) => {
  const uploadedFile = req.file;
  const preset = typeof req.body.preset === "string" ? req.body.preset : "";

  if (!uploadedFile) {
    res.status(400).json({ ok: false, error: "PDF 파일이 없습니다." });
    return;
  }

  if (path.extname(uploadedFile.originalname).toLowerCase() !== ".pdf") {
    await safeUnlink(uploadedFile.path);
    res.status(400).json({ ok: false, error: "PDF 파일만 인쇄할 수 있습니다." });
    return;
  }

  try {
    const requestConfig = buildPrintConfig({
      preset,
      duplex: typeof req.body.duplex === "string" ? req.body.duplex : "",
      colorMode: typeof req.body.colorMode === "string" ? req.body.colorMode : "",
      numberUp: typeof req.body.numberUp === "string" ? req.body.numberUp : "",
    });
    const output = await runHarness([
      "print",
      uploadedFile.path,
      "--queue-name",
      QUEUE_NAME,
      "--preset-source",
      PRESET_SOURCE,
      "--duplex",
      requestConfig.duplexMode,
      ...flattenOptions(requestConfig.options),
    ]);

    res.json({
      ok: true,
      output: output || `${requestConfig.title} 설정으로 인쇄 요청을 보냈습니다.`,
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: normalizeError(error),
    });
  } finally {
    await safeUnlink(uploadedFile.path);
  }
});

app.use((_req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.listen(PORT, () => {
  console.log(`Printer Launcher Web listening on http://127.0.0.1:${PORT}`);
});

function getPresetConfig(preset) {
  const table = {
    duplexColor: {
      title: "양면 컬러",
      duplexMode: "long-edge",
      options: [["CNColorMode", "color"]],
    },
    duplexMonochrome: {
      title: "양면 흑백",
      duplexMode: "long-edge",
      options: [["CNColorMode", "mono"]],
    },
    twoUpColor: {
      title: "한 장에 두 페이지",
      duplexMode: "long-edge",
      options: [
        ["CNColorMode", "color"],
        ["number-up", "2"],
      ],
    },
    singleSidedColor: {
      title: "단면 컬러",
      duplexMode: "one-sided",
      options: [["CNColorMode", "color"]],
    },
  };

  return table[preset] || table.duplexColor;
}

function buildPrintConfig({ preset, duplex, colorMode, numberUp }) {
  if (preset) {
    return getPresetConfig(preset);
  }

  const resolvedDuplex = normalizeDuplex(duplex);
  const resolvedColorMode = normalizeColorMode(colorMode);
  const resolvedNumberUp = normalizeNumberUp(numberUp);

  const options = [["CNColorMode", resolvedColorMode]];
  if (resolvedNumberUp !== "1") {
    options.push(["number-up", resolvedNumberUp]);
  }

  return {
    title: buildConfigTitle({
      duplex: resolvedDuplex,
      colorMode: resolvedColorMode,
      numberUp: resolvedNumberUp,
    }),
    duplexMode: resolvedDuplex,
    options,
  };
}

function normalizeDuplex(value) {
  return ["long-edge", "short-edge", "one-sided"].includes(value) ? value : "long-edge";
}

function normalizeColorMode(value) {
  return value === "mono" ? "mono" : "color";
}

function normalizeNumberUp(value) {
  return value === "2" ? "2" : "1";
}

function buildConfigTitle({ duplex, colorMode, numberUp }) {
  const parts = [];
  if (duplex === "one-sided") {
    parts.push("단면");
  } else {
    parts.push("양면");
  }
  parts.push(colorMode === "mono" ? "흑백" : "컬러");
  if (numberUp === "2") {
    parts.push("2-up");
  }
  return parts.join(" ");
}

function flattenOptions(options) {
  return options.flatMap(([key, value]) => ["--option", `${key}=${value}`]);
}

function normalizeError(error) {
  if (error instanceof Error) {
    return error.message || "요청 처리 중 오류가 발생했습니다.";
  }
  return "요청 처리 중 오류가 발생했습니다.";
}

function runHarness(args) {
  return new Promise((resolve, reject) => {
    const process = spawn("/usr/bin/python3", [HARNESS_PATH, ...args], {
      stdio: ["ignore", "pipe", "pipe"],
    });

    let output = "";
    process.stdout.on("data", (chunk) => {
      output += chunk.toString();
    });
    process.stderr.on("data", (chunk) => {
      output += chunk.toString();
    });

    process.on("error", (error) => {
      reject(error);
    });

    process.on("close", (code) => {
      const trimmed = output.trim();
      if (code === 0) {
        resolve(trimmed);
      } else {
        reject(new Error(trimmed || "인쇄 하네스 실행에 실패했습니다."));
      }
    });
  });
}

async function safeUnlink(filePath) {
  try {
    await fs.unlink(filePath);
  } catch {
  }
}

async function readUserQueueFallback(queueName) {
  try {
    const lpoptionsPath = path.join(os.homedir(), ".cups", "lpoptions");
    const raw = await fs.readFile(lpoptionsPath, "utf8");
    const line = raw
      .split("\n")
      .map((entry) => entry.trim())
      .find((entry) => entry.startsWith(`Default ${queueName} `) || entry === `Default ${queueName}`);

    if (!line) {
      return null;
    }

    const tokens = line.split(/\s+/).slice(2);
    const optionMap = new Map();
    for (const token of tokens) {
      const separatorIndex = token.indexOf("=");
      if (separatorIndex === -1) {
        continue;
      }
      optionMap.set(token.slice(0, separatorIndex), token.slice(separatorIndex + 1));
    }

    const lines = [
      "직접 CUPS 상태 조회는 이 실행 컨텍스트에서 실패했습니다.",
      `저장된 기본 큐 설정은 확인됐습니다: ${queueName}`,
    ];

    const sides = optionMap.get("sides");
    if (sides) {
      lines.push(`양면 설정: ${sides}`);
    }

    const inputSlot = optionMap.get("InputSlot");
    if (inputSlot) {
      lines.push(`급지: ${inputSlot}`);
    }

    const resolution = optionMap.get("Resolution");
    if (resolution) {
      lines.push(`해상도: ${resolution}`);
    }

    return lines.join("\n");
  } catch {
    return null;
  }
}
