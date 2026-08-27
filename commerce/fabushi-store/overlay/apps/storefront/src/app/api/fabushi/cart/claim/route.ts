import { NextRequest, NextResponse } from "next/server"

export async function GET(request: NextRequest) {
  const cartId = String(request.nextUrl.searchParams.get("cart_id") || "").trim()
  const countryCode = String(request.nextUrl.searchParams.get("country_code") || "us").trim().toLowerCase()

  if (!/^cart_[A-Za-z0-9_-]+$/.test(cartId)) {
    return NextResponse.json({ error: "invalid cart_id" }, { status: 400 })
  }
  if (!/^[a-z]{2}$/.test(countryCode)) {
    return NextResponse.json({ error: "invalid country_code" }, { status: 400 })
  }

  const target = new URL(`/${countryCode}/checkout`, request.nextUrl.origin)
  const response = NextResponse.redirect(target)
  response.cookies.set("_medusa_cart_id", cartId, {
    maxAge: 60 * 60 * 24 * 7,
    httpOnly: true,
    sameSite: "strict",
    secure: process.env.NODE_ENV === "production",
    path: "/",
  })
  return response
}
