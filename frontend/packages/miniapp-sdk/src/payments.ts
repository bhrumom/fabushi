import { isUnknownMethod } from "./errors";
import type {
  AnyRecord,
  CreateInvoiceInput,
  Invoice,
  InvoicePaymentResult,
  WalletBalance,
} from "./types";
import type { HostInvoker } from "./auth";

function readId(invoice: string | Invoice): string {
  if (typeof invoice === "string") return invoice;
  return String(invoice.invoiceId ?? invoice.id ?? invoice.orderId ?? "");
}

function normalizeInvoice(raw: AnyRecord, source: CreateInvoiceInput): Invoice {
  const id = String(raw.invoiceId ?? raw.id ?? raw.orderId ?? `inv_${Date.now()}`);
  return {
    ...raw,
    id,
    invoiceId: String(raw.invoiceId ?? id),
    orderId: typeof raw.orderId === "string" ? raw.orderId : undefined,
    amount: typeof raw.amount === "number" ? raw.amount : source.amount,
    currency: String(raw.currency ?? source.currency ?? "FUDE_JIN"),
    status: String(raw.status ?? "created"),
  };
}

function normalizePayment(raw: AnyRecord, invoiceId?: string): InvoicePaymentResult {
  const status = String(raw.status ?? raw.resultStatus ?? raw.tradeStatus ?? "").toUpperCase();
  const paid = raw.paid === true || ["PAID", "SUCCESS", "TRADE_SUCCESS", "9000"].includes(status);
  const pending = raw.pending === true || ["PENDING", "WAIT_BUYER_PAY", "8000", "6004"].includes(status);
  return {
    ...raw,
    invoiceId: String(raw.invoiceId ?? raw.id ?? invoiceId ?? ""),
    orderId: typeof raw.orderId === "string" ? raw.orderId : undefined,
    status: paid ? "paid" : pending ? "pending" : String(raw.status ?? (status.toLowerCase() || "unknown")),
    paid,
    pending,
  };
}

export class PaymentsModule {
  private readonly invoke: HostInvoker;

  constructor(invoke: HostInvoker) {
    this.invoke = invoke;
  }

  async createInvoice(input: CreateInvoiceInput): Promise<Invoice> {
    try {
      const data = await this.invoke<AnyRecord>("payments.createInvoice", input);
      return normalizeInvoice(data, input);
    } catch (error) {
      if (!isUnknownMethod(error)) throw error;
      const legacy = await this.invoke<AnyRecord>("payments.alipay.createOrder", {
        productId: input.productId ?? input.sku,
        title: input.title,
        subject: input.subject ?? input.title ?? input.description,
        amount: input.amount,
        priceLabel: input.priceLabel,
        metadata: input.metadata,
      });
      return normalizeInvoice({ ...legacy, currency: input.currency ?? "CNY" }, input);
    }
  }

  async openInvoice(invoice: string | Invoice): Promise<InvoicePaymentResult> {
    const invoiceId = readId(invoice);
    const invoiceRecord = typeof invoice === "string" ? { invoiceId } : invoice;
    try {
      const data = await this.invoke<AnyRecord>("payments.openInvoice", { ...invoiceRecord, invoiceId });
      return normalizePayment(data, invoiceId);
    } catch (error) {
      if (!isUnknownMethod(error)) throw error;
      const data = await this.invoke<AnyRecord>("payments.alipay.pay", invoiceRecord as AnyRecord);
      return normalizePayment(data, invoiceId);
    }
  }

  async queryInvoice(invoice: string | Invoice): Promise<InvoicePaymentResult> {
    const invoiceId = readId(invoice);
    const orderId = typeof invoice === "string" ? invoice : invoice.orderId ?? invoice.invoiceId ?? invoice.id;
    try {
      const data = await this.invoke<AnyRecord>("payments.queryInvoice", { invoiceId });
      return normalizePayment(data, invoiceId);
    } catch (error) {
      if (!isUnknownMethod(error)) throw error;
      const data = await this.invoke<AnyRecord>("payments.alipay.queryOrder", { orderId });
      return normalizePayment(data, invoiceId);
    }
  }

  async getWalletBalance(currency = "FUDE_JIN"): Promise<WalletBalance> {
    try {
      return await this.invoke<WalletBalance>("wallet.getBalance", { currency });
    } catch (error) {
      if (!isUnknownMethod(error)) throw error;
      return await this.invoke<WalletBalance>("payments.getWalletBalance", { currency });
    }
  }
}
