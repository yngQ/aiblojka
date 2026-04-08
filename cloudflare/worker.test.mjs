import test from "node:test";
import assert from "node:assert/strict";

import worker from "./worker.js";

const ORIGIN = "https://yngq.github.io";
const WORKER_URL = "https://aiblojka-proxy.test/";

function buildJsonRequest(payload) {
  return new Request(WORKER_URL, {
    method: "POST",
    headers: {
      Origin: ORIGIN,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

test("sends multipart payload to Workers AI and returns success contract", async () => {
  /** @type {unknown} */
  let capturedInput;

  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "dramatic sunrise over city skyline",
      format: "long",
    }),
    {
      AI: {
        run: async (_model, input) => {
          capturedInput = input;
          return { image: "aGVsbG8=" };
        },
      },
    }
  );

  assert.equal(response.status, 200);

  assert.ok(capturedInput && typeof capturedInput === "object");
  assert.ok("multipart" in capturedInput);
  assert.ok(capturedInput.multipart);
  assert.equal(typeof capturedInput.multipart.contentType, "string");
  assert.match(capturedInput.multipart.contentType, /^multipart\/form-data;\s*boundary=/i);
  assert.equal(typeof capturedInput.multipart.body?.getReader, "function");

  const body = await response.json();
  assert.deepEqual(body, {
    imageBase64: "aGVsbG8=",
    mimeType: "image/png",
  });
});

test("passes reference image as input_image_0 multipart part", async () => {
  /** @type {unknown} */
  let capturedInput;

  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test with reference",
      format: "short",
      referenceImageBase64: "aGVsbG8=",
      referenceMimeType: "image/png",
    }),
    {
      AI: {
        run: async (_model, input) => {
          capturedInput = input;
          return { image: "aGVsbG8=" };
        },
      },
    }
  );

  assert.equal(response.status, 200);
  assert.ok(capturedInput && typeof capturedInput === "object" && capturedInput.multipart);

  const multipartResponse = new Response(capturedInput.multipart.body, {
    headers: { "Content-Type": capturedInput.multipart.contentType },
  });
  const rawMultipart = await multipartResponse.text();

  assert.match(rawMultipart, /name="prompt"/);
  assert.match(rawMultipart, /name="width"/);
  assert.match(rawMultipart, /name="height"/);
  assert.match(rawMultipart, /name="input_image_0"/);
  assert.match(rawMultipart, /filename="reference\.png"/);
  assert.match(rawMultipart, /Content-Type: image\/png/i);
});

test("returns INVALID_REQUEST for malformed reference image base64", async () => {
  let aiRunCalled = false;

  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test",
      format: "short",
      referenceImageBase64: "not-valid-base64***",
      referenceMimeType: "image/png",
    }),
    {
      AI: {
        run: async () => {
          aiRunCalled = true;
          return { image: "aGVsbG8=" };
        },
      },
    }
  );

  assert.equal(aiRunCalled, false);
  assert.equal(response.status, 400);

  const body = await response.json();
  assert.equal(body?.error?.code, "INVALID_REQUEST");
  assert.equal(body?.error?.message, "Invalid reference image encoding.");
});

test("returns INTERNAL_ERROR when multipart payload cannot be built", async () => {
  const originalFormData = globalThis.FormData;
  let aiRunCalled = false;

  class ThrowingFormData {
    constructor() {
      throw new Error("synthetic multipart failure");
    }
  }

  globalThis.FormData = ThrowingFormData;

  try {
    const response = await worker.fetch(
      buildJsonRequest({
        prompt: "test",
        format: "long",
      }),
      {
        AI: {
          run: async () => {
            aiRunCalled = true;
            return { image: "aGVsbG8=" };
          },
        },
      }
    );

    assert.equal(aiRunCalled, false);
    assert.equal(response.status, 500);

    const body = await response.json();
    assert.equal(body?.error?.code, "INTERNAL_ERROR");
    assert.equal(body?.error?.message, "Server failed to prepare the AI request.");
  } finally {
    globalThis.FormData = originalFormData;
  }
});

test("does not treat non-DOMException errors as invalid base64 encoding", async () => {
  const originalFormData = globalThis.FormData;
  let aiRunCalled = false;

  class ThrowingFormData {
    constructor() {
      throw new Error("invalid character in multipart boundary generation");
    }
  }

  globalThis.FormData = ThrowingFormData;

  try {
    const response = await worker.fetch(
      buildJsonRequest({
        prompt: "test",
        format: "long",
      }),
      {
        AI: {
          run: async () => {
            aiRunCalled = true;
            return { image: "aGVsbG8=" };
          },
        },
      }
    );

    assert.equal(aiRunCalled, false);
    assert.equal(response.status, 500);

    const body = await response.json();
    assert.equal(body?.error?.code, "INTERNAL_ERROR");
  } finally {
    globalThis.FormData = originalFormData;
  }
});

test("maps upstream required-properties multipart error to BAD_REQUEST", async () => {
  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test",
      format: "long",
    }),
    {
      AI: {
        run: async () => {
          throw new Error("5006: Error: required properties at '/' are 'multipart'");
        },
      },
    }
  );

  assert.equal(response.status, 400);
  const body = await response.json();
  assert.equal(body?.error?.code, "BAD_REQUEST");
});

test("maps structured upstream 429 to QUOTA_EXCEEDED", async () => {
  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test",
      format: "long",
    }),
    {
      AI: {
        run: async () => {
          throw { status: 429, code: "rate_limit_exceeded", message: "too many requests" };
        },
      },
    }
  );

  assert.equal(response.status, 429);
  const body = await response.json();
  assert.equal(body?.error?.code, "QUOTA_EXCEEDED");
});

test("maps structured upstream 400 to BAD_REQUEST", async () => {
  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test",
      format: "long",
    }),
    {
      AI: {
        run: async () => {
          throw { status: 400, code: "invalid_request", message: "schema mismatch" };
        },
      },
    }
  );

  assert.equal(response.status, 400);
  const body = await response.json();
  assert.equal(body?.error?.code, "BAD_REQUEST");
});

test("keeps generic validation-like upstream errors as UPSTREAM_ERROR", async () => {
  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test",
      format: "long",
    }),
    {
      AI: {
        run: async () => {
          throw new Error("Internal validation pipeline timeout");
        },
      },
    }
  );

  assert.equal(response.status, 502);
  const body = await response.json();
  assert.equal(body?.error?.code, "UPSTREAM_ERROR");
});

test("prefers structured status over message heuristics", async () => {
  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test",
      format: "long",
    }),
    {
      AI: {
        run: async () => {
          throw { status: 500, message: "quota exceeded" };
        },
      },
    }
  );

  assert.equal(response.status, 502);
  const body = await response.json();
  assert.equal(body?.error?.code, "UPSTREAM_ERROR");
});

test("maps structured safety_block code to SAFETY_BLOCK", async () => {
  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test",
      format: "long",
    }),
    {
      AI: {
        run: async () => {
          throw { status: 451, code: "safety_block", message: "content policy violation" };
        },
      },
    }
  );

  assert.equal(response.status, 451);
  const body = await response.json();
  assert.equal(body?.error?.code, "SAFETY_BLOCK");
});

test("does not map unknown structured code with safety substring to SAFETY_BLOCK", async () => {
  // Structured metadata is present → text heuristics are skipped.
  // Only known exact codes trigger SAFETY_BLOCK; unknown codes fall through to UPSTREAM_ERROR.
  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test",
      format: "long",
    }),
    {
      AI: {
        run: async () => {
          throw { code: "content_safety_error", message: "safety check failed" };
        },
      },
    }
  );

  assert.equal(response.status, 502);
  const body = await response.json();
  assert.equal(body?.error?.code, "UPSTREAM_ERROR");
});

test("maps unstructured safety message to SAFETY_BLOCK via legacy heuristics", async () => {
  const response = await worker.fetch(
    buildJsonRequest({
      prompt: "test",
      format: "long",
    }),
    {
      AI: {
        run: async () => {
          throw new Error("safety filter triggered");
        },
      },
    }
  );

  assert.equal(response.status, 451);
  const body = await response.json();
  assert.equal(body?.error?.code, "SAFETY_BLOCK");
});
