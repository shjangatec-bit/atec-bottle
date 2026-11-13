// 유리병 편지 : Supabase 연결 정보 (공개용 키만 넣습니다. Secret/service_role 키는 절대 넣지 마세요)
window.BOTTLE_CONFIG = {
  url: 'https://aiwzaidfpnbceujyeeqa.supabase.co',
  key: 'sb_publishable_aT3rn4dWCAazag0ZKW_hTA_-xHzfcyS'
};

// 공통 API 호출
window.bottleApi = (function () {
  const C = window.BOTTLE_CONFIG;
  async function call(path, { method = 'POST', body, token, prefer } = {}) {
    const headers = { apikey: C.key, 'Content-Type': 'application/json' };
    if (token) headers.Authorization = 'Bearer ' + token;
    if (prefer) headers.Prefer = prefer;
    let res;
    try {
      res = await fetch(C.url + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
    } catch (e) {
      throw new Error('서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch (e) { data = text; }
    if (!res.ok) {
      const msg = (data && (data.message || data.msg || data.error_description || data.error)) || ('오류가 발생했습니다 (' + res.status + ')');
      const err = new Error(msg); err.status = res.status; throw err;
    }
    return data;
  }
  return {
    rpc: (fn, args, token) => call('/rest/v1/rpc/' + fn, { body: args || {}, token }),
    call
  };
})();
