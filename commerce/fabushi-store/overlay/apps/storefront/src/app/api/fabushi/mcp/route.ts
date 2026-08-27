import { NextRequest, NextResponse } from "next/server"

const backendUrl = (process.env.NEXT_PUBLIC_MEDUSA_BACKEND_URL || "http://localhost:9000").replace(/\/$/, "")
const publishableKey = process.env.NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY || ""
const storefrontUrl = (process.env.NEXT_PUBLIC_BASE_URL || "https://shop.ombhrum.com").replace(/\/$/, "")

const tools = [
  {
    name: "search_products",
    description: "Search purchasable products and variants in the Medusa catalog.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string" },
        country_code: { type: "string", default: "us" },
        limit: { type: "integer", minimum: 1, maximum: 24, default: 12 },
      },
      required: ["query"],
      additionalProperties: false,
    },
  },
  {
    name: "get_product",
    description: "Get a product with variants, calculated prices, images and inventory.",
    inputSchema: {
      type: "object",
      properties: {
        product_id: { type: "string" },
        country_code: { type: "string", default: "us" },
      },
      required: ["product_id"],
      additionalProperties: false,
    },
  },
  {
    name: "create_cart",
    description: "Create a Medusa cart for a country/region.",
    inputSchema: {
      type: "object",
      properties: { country_code: { type: "string", default: "us" } },
      additionalProperties: false,
    },
  },
  {
    name: "get_cart",
    description: "Read an existing Medusa cart and totals.",
    inputSchema: {
      type: "object",
      properties: { cart_id: { type: "string" } },
      required: ["cart_id"],
      additionalProperties: false,
    },
  },
  {
    name: "add_to_cart",
    description: "Add a product variant to an existing Medusa cart.",
    inputSchema: {
      type: "object",
      properties: {
        cart_id: { type: "string" },
        variant_id: { type: "string" },
        quantity: { type: "integer", minimum: 1, maximum: 20, default: 1 },
      },
      required: ["cart_id", "variant_id"],
      additionalProperties: false,
    },
  },
  {
    name: "remove_from_cart",
    description: "Remove one line item from a Medusa cart.",
    inputSchema: {
      type: "object",
      properties: {
        cart_id: { type: "string" },
        line_item_id: { type: "string" },
      },
      required: ["cart_id", "line_item_id"],
      additionalProperties: false,
    },
  },
  {
    name: "prepare_checkout",
    description: "Create a browser handoff URL for the normal storefront checkout using the same cart.",
    inputSchema: {
      type: "object",
      properties: {
        cart_id: { type: "string" },
        country_code: { type: "string", default: "us" },
      },
      required: ["cart_id"],
      additionalProperties: false,
    },
  },
  {
    name: "place_order",
    description: "Complete a ready Medusa cart. Fabushi must obtain explicit user approval before calling this tool.",
    inputSchema: {
      type: "object",
      properties: { cart_id: { type: "string" } },
      required: ["cart_id"],
      additionalProperties: false,
    },
  },
]

type Json = Record<string, any>

function medusaHeaders(json = false) {
  if (!publishableKey) throw new Error("NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY is not configured")
  return {
    "x-publishable-api-key": publishableKey,
    ...(json ? { "content-type": "application/json" } : {}),
  }
}

async function storeFetch(path: string, init: RequestInit = {}) {
  const response = await fetch(`${backendUrl}${path}`, {
    ...init,
    headers: { ...medusaHeaders(Boolean(init.body)), ...(init.headers || {}) },
    cache: "no-store",
  })
  const text = await response.text()
  let payload: any = null
  try {
    payload = text ? JSON.parse(text) : null
  } catch {
    payload = { message: text }
  }
  if (!response.ok) {
    throw new Error(payload?.message || `Medusa Store API returned ${response.status}`)
  }
  return payload
}

function countryCode(value: unknown) {
  const code = String(value || "us").trim().toLowerCase()
  if (!/^[a-z]{2}$/.test(code)) throw new Error("country_code must be a two-letter ISO code")
  return code
}

function requiredId(value: unknown, field: string, prefix?: string) {
  const id = String(value || "").trim()
  if (!id || (prefix && !id.startsWith(prefix))) throw new Error(`${field} is invalid`)
  return id
}

async function regionForCountry(code: string) {
  const payload = await storeFetch("/store/regions?limit=100")
  const region = (payload.regions || []).find((candidate: any) =>
    (candidate.countries || []).some((country: any) => String(country.iso_2 || "").toLowerCase() === code)
  )
  if (!region) throw new Error(`No Medusa region serves country ${code}`)
  return region
}

async function callTool(name: string, args: Json) {
  if (name === "search_products") {
    const code = countryCode(args.country_code)
    const region = await regionForCountry(code)
    const params = new URLSearchParams({
      q: String(args.query || "").trim(),
      limit: String(Math.max(1, Math.min(24, Number(args.limit) || 12))),
      region_id: region.id,
      fields: "*variants.calculated_price,+variants.inventory_quantity,*variants.images,*variants.options,+metadata,+tags",
    })
    if (!params.get("q")) throw new Error("query is required")
    return storeFetch(`/store/products?${params.toString()}`)
  }

  if (name === "get_product") {
    const code = countryCode(args.country_code)
    const region = await regionForCountry(code)
    const id = requiredId(args.product_id, "product_id", "prod_")
    const params = new URLSearchParams({
      region_id: region.id,
      fields: "*variants.calculated_price,+variants.inventory_quantity,*variants.images,*variants.options,+metadata,+tags",
    })
    return storeFetch(`/store/products/${encodeURIComponent(id)}?${params.toString()}`)
  }

  if (name === "create_cart") {
    const region = await regionForCountry(countryCode(args.country_code))
    return storeFetch("/store/carts", {
      method: "POST",
      body: JSON.stringify({ region_id: region.id }),
    })
  }

  if (name === "get_cart") {
    const id = requiredId(args.cart_id, "cart_id", "cart_")
    const fields = encodeURIComponent("*items,*items.product,*items.variant,+items.total,*promotions,+shipping_methods.name")
    return storeFetch(`/store/carts/${encodeURIComponent(id)}?fields=${fields}`)
  }

  if (name === "add_to_cart") {
    const cartId = requiredId(args.cart_id, "cart_id", "cart_")
    const variantId = requiredId(args.variant_id, "variant_id", "variant_")
    const quantity = Math.max(1, Math.min(20, Number(args.quantity) || 1))
    return storeFetch(`/store/carts/${encodeURIComponent(cartId)}/line-items`, {
      method: "POST",
      body: JSON.stringify({ variant_id: variantId, quantity }),
    })
  }

  if (name === "remove_from_cart") {
    const cartId = requiredId(args.cart_id, "cart_id", "cart_")
    const lineItemId = requiredId(args.line_item_id, "line_item_id", "item_")
    return storeFetch(`/store/carts/${encodeURIComponent(cartId)}/line-items/${encodeURIComponent(lineItemId)}`, {
      method: "DELETE",
    })
  }

  if (name === "prepare_checkout") {
    const cartId = requiredId(args.cart_id, "cart_id", "cart_")
    await storeFetch(`/store/carts/${encodeURIComponent(cartId)}?fields=id`)
    const code = countryCode(args.country_code)
    const url = new URL("/api/fabushi/cart/claim", storefrontUrl)
    url.searchParams.set("cart_id", cartId)
    url.searchParams.set("country_code", code)
    return { cart_id: cartId, checkout_url: url.toString(), requires_user_interaction: true }
  }

  if (name === "place_order") {
    const cartId = requiredId(args.cart_id, "cart_id", "cart_")
    return storeFetch(`/store/carts/${encodeURIComponent(cartId)}/complete`, { method: "POST" })
  }

  throw new Error(`Unknown tool: ${name}`)
}

function rpcResult(id: unknown, result: any) {
  return NextResponse.json({ jsonrpc: "2.0", id, result })
}

function rpcError(id: unknown, code: number, message: string) {
  return NextResponse.json({ jsonrpc: "2.0", id, error: { code, message } })
}

export async function GET() {
  return NextResponse.json({
    protocol: "fabushi.ai-commerce.mcp.v1",
    independentSite: storefrontUrl,
    tools,
  })
}

export async function POST(request: NextRequest) {
  let body: any
  try {
    body = await request.json()
  } catch {
    return rpcError(null, -32700, "Parse error")
  }

  const id = body?.id ?? null
  try {
    if (body?.method === "initialize") {
      return rpcResult(id, {
        protocolVersion: body?.params?.protocolVersion || "2025-06-18",
        capabilities: { tools: {} },
        serverInfo: { name: "fabushi-store-commerce", version: "1.0.0" },
      })
    }
    if (body?.method === "tools/list") return rpcResult(id, { tools })
    if (body?.method === "tools/call") {
      const name = String(body?.params?.name || "")
      const args = body?.params?.arguments && typeof body.params.arguments === "object" ? body.params.arguments : {}
      const result = await callTool(name, args)
      return rpcResult(id, {
        content: [{ type: "text", text: JSON.stringify(result) }],
        structuredContent: result,
        isError: false,
      })
    }
    if (body?.method === "notifications/initialized") return new NextResponse(null, { status: 202 })
    return rpcError(id, -32601, "Method not found")
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    if (body?.method === "tools/call") {
      return rpcResult(id, {
        content: [{ type: "text", text: message }],
        isError: true,
      })
    }
    return rpcError(id, -32000, message)
  }
}
