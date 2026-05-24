import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  handleCategorizeTransactionsRequest,
  normalizeCategoryName,
} from "./index.ts";

Deno.test("normalizes AI-created category names", () => {
  assertEquals(normalizeCategoryName(" pet-care!! "), "Pet Care");
  assertEquals(normalizeCategoryName("PET   care"), "Pet Care");
});

Deno.test("short category names fall back to Unknown", () => {
  assertEquals(normalizeCategoryName("C"), "Unknown");
  assertEquals(normalizeCategoryName("x"), "Unknown");
  assertEquals(normalizeCategoryName("--a--"), "Unknown");
  assertEquals(normalizeCategoryName("Gas"), "Gas");
});

Deno.test("unsafe category names fall back to Unknown", () => {
  assertEquals(normalizeCategoryName("https://example.com"), "Unknown");
  assertEquals(normalizeCategoryName("person@example.com"), "Unknown");
  assertEquals(normalizeCategoryName("<script>"), "Unknown");
  assertEquals(normalizeCategoryName("!!!"), "Unknown");
});

Deno.test("rejects invalid request shape before OpenAI call", async () => {
  const response = await handleCategorizeTransactionsRequest(
    new Request("http://localhost", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        allowedCategories: ["Unknown"],
        transactions: [],
      }),
    }),
  );

  assertEquals(response.status, 400);
  assertEquals(await response.json(), {
    error: "transactions must be a non-empty array",
  });
});

Deno.test("chunks large imports into smaller OpenAI calls", async () => {
  const restore = setOpenAiTestEnv();
  let callCount = 0;
  globalThis.fetch = async (_input, init) => {
    callCount += 1;
    const txs = transactionsFromOpenAiRequest(init);
    return openAiJsonResponse(
      txs.map((transaction) => ({
        key: transaction.k,
        categoryName: "Pet Care",
      })),
    );
  };

  try {
    const response = await handleCategorizeTransactionsRequest(
      validRequest(250),
    );
    const body = await response.json();

    assertEquals(response.status, 200);
    assertEquals(callCount, 5);
    assertEquals(body.errors, []);
    assertEquals(body.suggestions.length, 250);
    assertEquals(body.suggestions[0].categoryName, "Pet Care");
  } finally {
    restore();
  }
});

Deno.test("invalid model output falls back to Miscellaneous per transaction", async () => {
  const restore = setOpenAiTestEnv();
  globalThis.fetch = async () =>
    openAiCompactJsonResponse({
      "txn-0": "C",
      "txn-1": "Gas",
    });

  try {
    const response = await handleCategorizeTransactionsRequest(validRequest(3));
    const body = await response.json();

    assertEquals(response.status, 200);
    assertEquals(body.errors, []);
    assertEquals(body.suggestions, [
      { key: "txn-0", categoryName: "Miscellaneous" },
      { key: "txn-1", categoryName: "Gas" },
      { key: "txn-2", categoryName: "Miscellaneous" },
    ]);
  } finally {
    restore();
  }
});

Deno.test("failed chunks return Miscellaneous instead of failing the whole import", async () => {
  const restore = setOpenAiTestEnv();
  globalThis.fetch = async () =>
    new Response(JSON.stringify({ error: "rate limited" }), {
      status: 429,
      headers: { "Content-Type": "application/json" },
    });

  try {
    const response = await handleCategorizeTransactionsRequest(
      validRequest(120),
    );
    const body = await response.json();

    assertEquals(response.status, 200);
    assertEquals(body.errors.length, 3);
    assertEquals(body.suggestions.length, 120);
    assertEquals(
      body.suggestions.every((suggestion: { categoryName: string }) =>
        suggestion.categoryName === "Miscellaneous"
      ),
      true,
    );
  } finally {
    restore();
  }
});

Deno.test("deterministic categories bypass OpenAI for known merchants", async () => {
  const restore = setOpenAiTestEnv();
  let callCount = 0;
  globalThis.fetch = async () => {
    callCount += 1;
    throw new Error("OpenAI should not be called for deterministic rows");
  };

  try {
    const response = await handleCategorizeTransactionsRequest(
      validRequestWithTransactions([
        {
          key: "dunkin",
          date: "2026-01-07",
          amount: -4.55,
          description: "DUNKIN #304654 12/31 MOBILE PURCHASE SOMERVILLE MA",
        },
        {
          key: "bom",
          date: "2026-03-02",
          amount: -2.94,
          description: "TST* BOM DOUGH 02/28 MOBILE PURCHASE CAMBRIDGE MA",
        },
        {
          key: "dollar",
          date: "2026-01-08",
          amount: -14.08,
          description: "DOLLARTREE 01/08 MOBILE PURCHASE SOMERVILLE MA",
        },
        {
          key: "market",
          date: "2026-03-02",
          amount: -6.48,
          description: "PEARL ST MARKET 02/28 MOBILE PURCHASE SOMERVILLE MA",
        },
        {
          key: "atm",
          date: "2026-03-02",
          amount: -10,
          description:
            "BKOFAMERICA ATM 03/02 #XXXXX6083 WITHDRWL EAST CAMBRIDGE MA",
        },
        {
          key: "apple",
          date: "2026-01-07",
          amount: -14.86,
          description: "APPLE COM BILL 01/07 PURCHASE CUPERTINO CA",
        },
        {
          key: "amazon",
          date: "2026-04-17",
          amount: -14.99,
          description: "AMAZON PRIME*Z40F365E3 04/16 PURCHASE Amzn.com/bill WA",
        },
        {
          key: "planet",
          date: "2026-04-17",
          amount: -25.05,
          description:
            "PLANET FITNESS F DES:IClub Fees ID:PRXXXXX05909824 INDN:Pedro Martins",
        },
        {
          key: "cvs",
          date: "2026-03-02",
          amount: -12.36,
          description: "CVS/PHARMACY # 03/02 MOBILE PURCHASE CAMBRIDGE MA",
        },
        {
          key: "dsw",
          date: "2026-03-02",
          amount: -59.99,
          description: "DSW DOWNTOWN C 03/02 MOBILE PURCHASE BOSTON MA",
        },
        {
          key: "supabase",
          date: "2026-04-22",
          amount: -25,
          description: "SUPABASE 04/21 PURCHASE SINGAPORE",
        },
      ]),
    );
    const body = await response.json();

    assertEquals(response.status, 200);
    assertEquals(callCount, 0);
    assertEquals(body.errors, []);
    assertEquals(body.suggestions, [
      { key: "dunkin", categoryName: "Coffee / Quick Food" },
      { key: "bom", categoryName: "Coffee / Quick Food" },
      { key: "dollar", categoryName: "Shopping" },
      { key: "market", categoryName: "Grocery / Supermarket" },
      { key: "atm", categoryName: "Cash Withdrawal" },
      { key: "apple", categoryName: "Subscriptions" },
      { key: "amazon", categoryName: "Subscriptions" },
      { key: "planet", categoryName: "Subscriptions" },
      { key: "cvs", categoryName: "Pharmacy / Health" },
      { key: "dsw", categoryName: "Shoes / Clothing" },
      { key: "supabase", categoryName: "Software / Tools" },
    ]);
  } finally {
    restore();
  }
});

Deno.test("missing AI suggestions use deterministic fallback when available", async () => {
  const restore = setOpenAiTestEnv();
  globalThis.fetch = async () => openAiCompactJsonResponse({});

  try {
    const response = await handleCategorizeTransactionsRequest(
      validRequestWithTransactions([
        {
          key: "amazon",
          date: "2026-04-17",
          amount: -14.99,
          description: "AMAZON PRIME*Z40F365E3 04/16 PURCHASE Amzn.com/bill WA",
        },
        {
          key: "generic",
          date: "2026-04-17",
          amount: -14.99,
          description: "UNRECOGNIZED MERCHANT",
        },
      ]),
    );
    const body = await response.json();

    assertEquals(response.status, 200);
    assertEquals(body.errors, []);
    assertEquals(body.suggestions, [
      { key: "amazon", categoryName: "Subscriptions" },
      { key: "generic", categoryName: "Miscellaneous" },
    ]);
  } finally {
    restore();
  }
});

Deno.test("truncated AI response falls back per row", async () => {
  const restore = setOpenAiTestEnv();
  globalThis.fetch = async () =>
    openAiCompactJsonResponse({}, { finishReason: "length" });

  try {
    const response = await handleCategorizeTransactionsRequest(
      validRequestWithTransactions([
        {
          key: "cvs",
          date: "2026-03-02",
          amount: -12.36,
          description: "CVS/PHARMACY # 03/02 MOBILE PURCHASE CAMBRIDGE MA",
        },
        {
          key: "generic",
          date: "2026-04-17",
          amount: -14.99,
          description: "UNRECOGNIZED MERCHANT",
        },
      ]),
    );
    const body = await response.json();

    assertEquals(response.status, 200);
    assertEquals(body.errors.length, 1);
    assertEquals(body.suggestions, [
      { key: "cvs", categoryName: "Pharmacy / Health" },
      { key: "generic", categoryName: "Miscellaneous" },
    ]);
  } finally {
    restore();
  }
});

Deno.test("negative AI income suggestions fall back safely", async () => {
  const restore = setOpenAiTestEnv();
  globalThis.fetch = async () =>
    openAiCompactJsonResponse({
      "txn-0": "Income / Payroll",
    });

  try {
    const response = await handleCategorizeTransactionsRequest(validRequest(1));
    const body = await response.json();

    assertEquals(response.status, 200);
    assertEquals(body.errors, []);
    assertEquals(body.suggestions, [
      { key: "txn-0", categoryName: "Miscellaneous" },
    ]);
  } finally {
    restore();
  }
});

function setOpenAiTestEnv() {
  const originalFetch = globalThis.fetch;
  const originalKey = Deno.env.get("OPENAI_API_KEY");
  Deno.env.set("OPENAI_API_KEY", "test-key");
  return () => {
    globalThis.fetch = originalFetch;
    if (originalKey == null) {
      Deno.env.delete("OPENAI_API_KEY");
    } else {
      Deno.env.set("OPENAI_API_KEY", originalKey);
    }
  };
}

function validRequest(count: number) {
  return validRequestWithTransactions(
    Array.from({ length: count }, (_, index) => ({
      key: `txn-${index}`,
      date: "2025-01-01",
      amount: -12.34,
      description: `Merchant ${index}`,
    })),
  );
}

function validRequestWithTransactions(transactions: TransactionFixture[]) {
  return new Request("http://localhost", {
    method: "POST",
    headers: {
      Authorization: "Bearer test-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      allowedCategories: ["Unknown"],
      transactions,
    }),
  });
}

type TransactionFixture = {
  key: string;
  date: string;
  amount: number;
  description: string;
};

function transactionsFromOpenAiRequest(init?: RequestInit) {
  const body = JSON.parse(String(init?.body ?? "{}"));
  const content = body.messages?.[1]?.content;
  if (typeof content !== "string") return [];
  const marker = "T:";
  const index = content.indexOf(marker);
  if (index < 0) return [];
  return JSON.parse(content.slice(index + marker.length)) as Array<{
    k: string;
  }>;
}

function openAiCompactJsonResponse(
  suggestions: Record<string, string>,
  options: { finishReason?: string } = {},
) {
  return new Response(
    JSON.stringify({
      choices: [
        {
          finish_reason: options.finishReason,
          message: {
            content: JSON.stringify({ s: suggestions }),
          },
        },
      ],
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    },
  );
}

function openAiJsonResponse(
  suggestions: Array<{ key: string; categoryName: string }>,
) {
  return new Response(
    JSON.stringify({
      choices: [
        {
          message: {
            content: JSON.stringify({ suggestions }),
          },
        },
      ],
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    },
  );
}
