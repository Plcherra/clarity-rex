const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const openAiModel = "gpt-4o-mini";
const maxTransactionsPerOpenAiCall = 50;
const maxOpenAiConcurrency = 6;
const maxOpenAiAttempts = 1;
const openAiRequestTimeoutMs = 20_000;
const openAiMaxTokens = 12_000;
const unknownCategoryName = "Unknown";
const automaticFallbackCategoryName = "Miscellaneous";
const maxCategoryNameLength = 40;
const minMeaningfulCategoryCharacters = 3;
const maxDescriptionLength = 80;

type TransactionInput = {
  key: string;
  date: string;
  amount: number;
  description: string;
};

type Suggestion = {
  key: string;
  categoryName: string;
};

type ChunkResult = {
  suggestions: Suggestion[];
  error?: string;
};

type CategoryRejectionReason =
  | "non_string"
  | "empty"
  | "too_long"
  | "unsafe"
  | "no_alphanumeric"
  | "too_short"
  | "empty_normalized";

function containsAny(haystack: string, needles: string[]): boolean {
  return needles.some((needle) => haystack.includes(needle));
}

function normalizedDescription(description: string): string {
  return description
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function isIncomeCategoryName(categoryName: string): boolean {
  return categoryName.trim().toLowerCase().startsWith("income");
}

function deterministicCategoryName(
  transaction: TransactionInput,
): string | null {
  const h = transaction.description.toLowerCase();
  const normalized = normalizedDescription(transaction.description);
  const has = (needles: string[]) =>
    containsAny(h, needles) || containsAny(normalized, needles);
  const isOutflow = transaction.amount < 0;
  if (
    has(["returned item", "insufficient funds"]) ||
    /\b(reversal|reversed|refunded|returned|nsf|return)\b/i.test(h)
  ) {
    return "Ignored";
  }
  if (
    has(["online banking payment to crd", "payment to crd"])
  ) {
    return "Credit Card Payment";
  }
  if (has(["zelle"]) && has(["payment to"])) {
    return "Transfer Out";
  }
  if (!isOutflow && has(["payroll", "des payroll", "des:payroll"])) {
    return "Income / Payroll";
  }
  if (
    !isOutflow && has(["zelle"]) &&
    (has(["payment from"]) || has(["transfer from"]))
  ) {
    return "Income / Zelle Received";
  }
  if (
    has(["atm"]) &&
    has(["withdrwl", "withdrawal", "cash withdrawal"])
  ) {
    return "Cash Withdrawal";
  }
  if (
    has([
      "bom dough",
      "dunkin",
      "dunkin donuts",
      "caffe nero",
      "starbucks",
      "tatte",
      "cafe",
      "coffee",
    ]) || /\bdd\b/i.test(transaction.description)
  ) {
    return "Coffee / Quick Food";
  }
  if (
    has([
      "uber eats",
      "doordash",
      "grubhub",
      "chipotle",
      "mcdonald",
      "burger king",
      "wendy",
      "sweetgreen",
      "restaurant",
      "tst ",
    ])
  ) {
    return "Food & Drink";
  }
  if (
    has([
      "pearl market",
      "pearl st market",
      "stop and shop",
      "market basket",
      "whole foods",
      "trader joe",
      "supermarket",
      "grocery",
    ])
  ) {
    return "Grocery / Supermarket";
  }
  if (
    has([
      "cvs",
      "cvs pharmacy",
      "walgreens",
      "rite aid",
      "riteaid",
      "pharmacy",
    ])
  ) {
    return "Pharmacy / Health";
  }
  if (has(["dsw", "nike", "adidas", "foot locker", "shoe"])) {
    return "Shoes / Clothing";
  }
  if (
    has([
      "apple com bill",
      "apple.com/bill",
      "amazon prime",
      "amzn com bill",
      "netflix",
      "spotify",
      "hulu",
      "youtube premium",
      "suno",
      "landr",
      "planet fitness",
    ])
  ) {
    return "Subscriptions";
  }
  if (
    has([
      "dollartree",
      "dollar tree",
      "amazon",
      "amzn",
      "walmart",
      "target",
      "costco",
      "tj maxx",
      "marshalls",
      "temu",
      "shein",
    ])
  ) {
    return "Shopping";
  }
  if (
    (has(["uber"]) && !has(["uber eats"])) ||
    has([
      "lyft",
      "taxi",
      "mbta",
      "shell",
      "exxon",
      "mobil gas",
      "parking",
      "toll",
    ])
  ) {
    return "Transportation";
  }
  if (has(["rent", "mortgage", "landlord", "lease"])) {
    return "Housing";
  }
  if (
    has([
      "verizon",
      "tmobile",
      "t mobile",
      "comcast",
      "xfinity",
      "spectrum",
      "electric",
      "gas bill",
      "water bill",
    ])
  ) {
    return "Bills & Utilities";
  }
  if (has(["supabase", "openai", "github", "cursor", "anthropic"])) {
    return "Software / Tools";
  }
  return null;
}

function normalizeSuggestionForTransaction(
  categoryName: unknown,
  transaction: TransactionInput,
  rejectedCategoryCounts?: Map<CategoryRejectionReason, number>,
): string {
  const normalized = normalizeCategoryName(
    categoryName,
    rejectedCategoryCounts,
  );
  if (normalized === unknownCategoryName) {
    return automaticFallbackCategoryName;
  }
  if (transaction.amount < 0 && isIncomeCategoryName(normalized)) {
    return deterministicCategoryName(transaction) ??
      automaticFallbackCategoryName;
  }
  return normalized;
}

function fallbackCategoryNameForTransaction(
  transaction: TransactionInput,
  rejectedCategoryCounts?: Map<CategoryRejectionReason, number>,
): string {
  const deterministic = deterministicCategoryName(transaction);
  if (!deterministic) return automaticFallbackCategoryName;
  return normalizeSuggestionForTransaction(
    deterministic,
    transaction,
    rejectedCategoryCounts,
  );
}

function jsonResponse(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

function compactTransaction(transaction: TransactionInput) {
  return {
    k: transaction.key,
    a: transaction.amount,
    m: transaction.description.slice(0, maxDescriptionLength),
  };
}

function unknownSuggestions(transactions: TransactionInput[]): Suggestion[] {
  return transactions.map((transaction) => ({
    key: transaction.key,
    categoryName: automaticFallbackCategoryName,
  }));
}

function isRetryableOpenAiError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  const message = error.message.toLowerCase();
  return (
    message.includes("timed out") ||
    message.includes("429") ||
    message.includes("500") ||
    message.includes("502") ||
    message.includes("503") ||
    message.includes("504") ||
    message.includes("network")
  );
}

async function fetchWithTimeout(
  input: string,
  init: RequestInit,
  timeoutMs: number,
) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error(`OpenAI request timed out after ${timeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function parseStringArray(value: unknown): string[] | null {
  if (!Array.isArray(value)) return null;
  const out: string[] = [];
  for (const item of value) {
    if (typeof item !== "string") return null;
    const trimmed = item.trim();
    if (trimmed.length > 0) out.push(trimmed);
  }
  return out;
}

function parseTransactions(value: unknown): TransactionInput[] | null {
  if (!Array.isArray(value)) return null;
  const out: TransactionInput[] = [];
  for (const item of value) {
    if (!item || typeof item !== "object") return null;
    const row = item as Record<string, unknown>;
    const key = row.key;
    const date = row.date;
    const amount = row.amount;
    const description = row.description;
    if (
      typeof key !== "string" ||
      key.trim().length === 0 ||
      typeof date !== "string" ||
      typeof amount !== "number" ||
      typeof description !== "string"
    ) {
      return null;
    }
    out.push({
      key: key.trim(),
      date,
      amount,
      description,
    });
  }
  return out;
}

function normalizedCategoryKey(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replaceAll("&", " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\band\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function meaningfulCategoryCharacterCount(raw: string): number {
  return Array.from(raw.matchAll(/[A-Za-z0-9]/g)).length;
}

function titleCaseWord(word: string): string {
  if (word.length === 0 || word === "/") return word;
  const lower = word.toLowerCase();
  return lower[0].toUpperCase() + lower.slice(1);
}

function recordCategoryRejection(
  reason: CategoryRejectionReason,
  rejectedCategoryCounts?: Map<CategoryRejectionReason, number>,
) {
  if (!rejectedCategoryCounts) return;
  rejectedCategoryCounts.set(
    reason,
    (rejectedCategoryCounts.get(reason) ?? 0) + 1,
  );
}

function logRejectedCategoryCounts(
  rejectedCategoryCounts: Map<CategoryRejectionReason, number>,
) {
  if (rejectedCategoryCounts.size === 0) return;
  console.warn("[Clarity][categorize-transactions] rejected category names", {
    reasons: Object.fromEntries(rejectedCategoryCounts),
  });
}

export function normalizeCategoryName(
  raw: unknown,
  rejectedCategoryCounts?: Map<CategoryRejectionReason, number>,
): string {
  if (typeof raw !== "string") {
    recordCategoryRejection("non_string", rejectedCategoryCounts);
    return unknownCategoryName;
  }
  const trimmed = raw.trim();
  if (trimmed.length === 0) {
    recordCategoryRejection("empty", rejectedCategoryCounts);
    return unknownCategoryName;
  }
  if (trimmed.length > maxCategoryNameLength) {
    recordCategoryRejection("too_long", rejectedCategoryCounts);
    return unknownCategoryName;
  }
  const lower = trimmed.toLowerCase();
  if (
    lower.startsWith("http://") ||
    lower.startsWith("https://") ||
    lower.includes("@") ||
    /[<>{}\[\]\\`~^=]/.test(trimmed)
  ) {
    recordCategoryRejection("unsafe", rejectedCategoryCounts);
    return unknownCategoryName;
  }
  if (!/[A-Za-z0-9]/.test(trimmed)) {
    recordCategoryRejection("no_alphanumeric", rejectedCategoryCounts);
    return unknownCategoryName;
  }
  const display = trimmed
    .replaceAll("&", " and ")
    .replace(/\s*\/\s*/g, " / ")
    .replace(/[\s\-_.,;:|!?'"()]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .split(" ")
    .map(titleCaseWord)
    .join(" ");
  if (
    meaningfulCategoryCharacterCount(display) <
      minMeaningfulCategoryCharacters
  ) {
    recordCategoryRejection("too_short", rejectedCategoryCounts);
    return unknownCategoryName;
  }
  if (
    display.length === 0 ||
    display.length > maxCategoryNameLength ||
    normalizedCategoryKey(display).length === 0
  ) {
    recordCategoryRejection("empty_normalized", rejectedCategoryCounts);
    return unknownCategoryName;
  }
  return display;
}

async function categorizeChunk({
  openAiApiKey,
  transactions,
  allowedCategories,
}: {
  openAiApiKey: string;
  transactions: TransactionInput[];
  allowedCategories: string[];
}): Promise<ChunkResult> {
  const deterministicSuggestions: Suggestion[] = [];
  const aiTransactions: TransactionInput[] = [];
  for (const transaction of transactions) {
    const deterministic = deterministicCategoryName(transaction);
    if (deterministic) {
      deterministicSuggestions.push({
        key: transaction.key,
        categoryName: normalizeCategoryName(deterministic),
      });
    } else {
      aiTransactions.push(transaction);
    }
  }
  if (aiTransactions.length === 0) {
    return { suggestions: deterministicSuggestions };
  }

  const system = `JSON only. Return {"s":{"KEY":"Category"}}. ` +
    `Categorize each tx. Use an allowed category if it fits; else short new category. ` +
    `No income for negative amounts. No merchant/private data. Unsafe/unsure="${automaticFallbackCategoryName}".`;
  const user = `C:${JSON.stringify(allowedCategories)}\n` +
    `T:${JSON.stringify(aiTransactions.map(compactTransaction))}`;

  let lastError: unknown;
  for (let attempt = 1; attempt <= maxOpenAiAttempts; attempt += 1) {
    try {
      const response = await fetchWithTimeout(
        "https://api.openai.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${openAiApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: openAiModel,
            temperature: 0.1,
            max_tokens: openAiMaxTokens,
            response_format: { type: "json_object" },
            messages: [
              { role: "system", content: system },
              { role: "user", content: user },
            ],
          }),
        },
        openAiRequestTimeoutMs,
      );

      let data: unknown;
      try {
        data = await response.json();
      } catch {
        throw new Error(
          `OpenAI returned a non-JSON response (${response.status})`,
        );
      }

      if (!response.ok) {
        const message = typeof data === "object" && data && "error" in data
          ? JSON.stringify((data as Record<string, unknown>).error)
          : JSON.stringify(data);
        throw new Error(
          `OpenAI request failed (${response.status}): ${message}`,
        );
      }

      const choices = (data as Record<string, unknown>).choices;
      if (!Array.isArray(choices) || choices.length === 0) {
        throw new Error("OpenAI response has no choices");
      }
      const first = choices[0] as Record<string, unknown>;
      if (first.finish_reason === "length") {
        throw new Error("OpenAI response was truncated");
      }
      const message = first.message as Record<string, unknown> | undefined;
      const content = message?.content;
      if (typeof content !== "string" || content.trim().length === 0) {
        throw new Error("OpenAI response content is empty");
      }

      let parsed: unknown;
      try {
        parsed = JSON.parse(content);
      } catch {
        throw new Error("OpenAI response content is not valid JSON");
      }

      const expectedKeys = new Set(
        aiTransactions.map((transaction) => transaction.key),
      );
      const transactionByKey = new Map(
        aiTransactions.map((transaction) => [transaction.key, transaction]),
      );
      const suggestionByKey = new Map<string, string>();
      const duplicateKeys = new Set<string>();
      const seen = new Set<string>();
      const rejectedCategoryCounts = new Map<CategoryRejectionReason, number>();
      const parsedRow = parsed as Record<string, unknown>;
      const compactSuggestions = parsedRow.s;
      if (compactSuggestions && typeof compactSuggestions === "object") {
        for (
          const [key, categoryName] of Object.entries(
            compactSuggestions as Record<string, unknown>,
          )
        ) {
          if (!expectedKeys.has(key) || seen.has(key)) {
            if (expectedKeys.has(key)) duplicateKeys.add(key);
            continue;
          }
          seen.add(key);
          suggestionByKey.set(
            key,
            normalizeSuggestionForTransaction(
              categoryName,
              transactionByKey.get(key)!,
              rejectedCategoryCounts,
            ),
          );
        }
      } else {
        const rawSuggestions = parsedRow.suggestions;
        if (!Array.isArray(rawSuggestions)) {
          throw new Error("OpenAI response missing suggestions");
        }
        for (const item of rawSuggestions) {
          if (!item || typeof item !== "object") continue;
          const row = item as Record<string, unknown>;
          const key = row.key;
          if (
            typeof key !== "string" || !expectedKeys.has(key) || seen.has(key)
          ) {
            if (typeof key === "string" && expectedKeys.has(key)) {
              duplicateKeys.add(key);
            }
            continue;
          }
          seen.add(key);
          suggestionByKey.set(
            key,
            normalizeSuggestionForTransaction(
              row.categoryName,
              transactionByKey.get(key)!,
              rejectedCategoryCounts,
            ),
          );
        }
      }
      logRejectedCategoryCounts(rejectedCategoryCounts);

      const out: Suggestion[] = [...deterministicSuggestions];
      for (const transaction of aiTransactions) {
        out.push({
          key: transaction.key,
          categoryName: duplicateKeys.has(transaction.key)
            ? fallbackCategoryNameForTransaction(
              transaction,
              rejectedCategoryCounts,
            )
            : suggestionByKey.get(transaction.key) ??
              fallbackCategoryNameForTransaction(
                transaction,
                rejectedCategoryCounts,
              ),
        });
      }
      return { suggestions: out };
    } catch (error) {
      lastError = error;
      if (attempt >= maxOpenAiAttempts || !isRetryableOpenAiError(error)) {
        break;
      }
    }
  }

  const message = lastError instanceof Error
    ? lastError.message
    : "Could not categorize chunk";
  return {
    suggestions: [
      ...deterministicSuggestions,
      ...aiTransactions.map((transaction) => ({
        key: transaction.key,
        categoryName: fallbackCategoryNameForTransaction(transaction),
      })),
    ],
    error: message,
  };
}

export async function handleCategorizeTransactionsRequest(req: Request) {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return jsonResponse({ error: "Missing Supabase auth token" }, 401);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const transactions = parseTransactions(payload.transactions);
  const requestedCategories = parseStringArray(payload.allowedCategories);
  if (!transactions || transactions.length === 0) {
    return jsonResponse(
      { error: "transactions must be a non-empty array" },
      400,
    );
  }
  if (!requestedCategories || requestedCategories.length === 0) {
    return jsonResponse(
      { error: "allowedCategories must be a non-empty string array" },
      400,
    );
  }

  const openAiApiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openAiApiKey) {
    return jsonResponse({ error: "Missing OPENAI_API_KEY secret" }, 500);
  }
  const apiKey = openAiApiKey;

  const allowedCategories = Array.from(
    new Set([
      ...requestedCategories,
      unknownCategoryName,
      automaticFallbackCategoryName,
    ]),
  );
  const categoryByNormalizedName = new Map(
    allowedCategories.map((
      category,
    ) => [normalizedCategoryKey(category), category]),
  );
  const chunks = chunk(transactions, maxTransactionsPerOpenAiCall);
  const suggestions: Suggestion[] = [];
  const errors: string[] = [];
  let nextChunkIndex = 0;

  async function worker() {
    while (true) {
      const chunkIndex = nextChunkIndex;
      if (chunkIndex >= chunks.length) return;
      nextChunkIndex += 1;
      const result = await categorizeChunk({
        openAiApiKey: apiKey,
        transactions: chunks[chunkIndex],
        allowedCategories: Array.from(categoryByNormalizedName.values()),
      });
      suggestions.push(...result.suggestions);
      if (result.error) {
        errors.push(
          `chunk ${chunkIndex + 1}/${chunks.length}: ${result.error}`,
        );
      }
    }
  }

  await Promise.all(
    Array.from(
      { length: Math.min(chunks.length, maxOpenAiConcurrency) },
      () => worker(),
    ),
  );

  return jsonResponse({ suggestions, errors }, 200);
}

if (import.meta.main) {
  Deno.serve(handleCategorizeTransactionsRequest);
}
