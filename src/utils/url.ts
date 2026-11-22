/** 서버에서 온 URL 은 http/https 일 때만 링크로 쓴다 (javascript:, data: 등은 null). */
export function safeHttpUrl(value: string | null | undefined): string | null {
  if (!value) return null;
  try {
    const url = new URL(value.trim());
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.href : null;
  } catch {
    return null;
  }
}
