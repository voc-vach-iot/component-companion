/* Component Companion - lấy linh kiện từ Shopee bằng cách đọc HTML trang:
 * - Đơn mua (shopee.vn/user/purchase): mọi sản phẩm đang hiện trên trang
 *   (có nút cuộn để tải thêm đơn).
 * - Chi tiết đơn hàng: sản phẩm của đơn, kèm link sản phẩm.
 * - Trang sản phẩm: mỗi tổ hợp phân loại 1 dòng, tự bấm từng phân loại để
 *   đọc giá.
 * Cho xem / sửa rồi sao chép JSON để dán vào app (Dữ liệu > Nhập linh kiện >
 * Dán từ clipboard) hoặc tải CSV.
 * Shopee đổi tên class liên tục nên chỉ dựa vào chữ hiển thị ("Xem Shop",
 * "x2", "₫", "Phân loại hàng:") và thuộc tính ổn định (aria-label, href).
 * Chỉ dùng comment khối và dấu ; để chạy được khi bị gộp thành 1 dòng. */
(function () {
  var ID = "cc-shopee-panel";
  var doc = document;

  /* ---------- Đọc chữ ---------- */

  /* Các dòng chữ hiển thị trong [el], mỗi text node 1 dòng (không dùng
   * innerText để chạy được cả khi chưa render). */
  function lines(el) {
    var out = [];
    var walker = doc.createTreeWalker(el, 4 /* NodeFilter.SHOW_TEXT */);
    var node;
    while ((node = walker.nextNode())) {
      var p = node.parentElement;
      if (p && /^(SCRIPT|STYLE|NOSCRIPT|TITLE)$/.test(p.tagName)) { continue; }
      if (p && p.closest && p.closest("#" + ID)) { continue; }
      var t = node.nodeValue.replace(/\s+/g, " ").trim();
      if (t) { out.push(t); }
    }
    return out;
  }

  var PRICE = /^-?[\d.]+\s*₫$/;
  var QTY = /^x\s*(\d+)$/i;

  function parsePrice(text) {
    var m = String(text || "").match(/([\d.]+)\s*₫/);
    return m ? parseInt(m[1].replace(/\./g, ""), 10) || 0 : 0;
  }

  function guessUnits(text) {
    var s = String(text || "").toLowerCase().replace(/_/g, " ");
    var m = s.match(/(\d+)\s*(c[áa]i|chi[ếe]c|con|pcs|pc|v[iỉ]ên|c[ặa]p|b[ộo]|cu[ộo]n|m[ée]t)(?![a-zà-ỹ])/) ||
      s.match(/(?:g[óo]i|set|s[ée]t|combo|t[úu]i|b[ịi]ch|h[ộo]p)\s*(\d+)/) ||
      s.match(/(?:^|\s)x\s*(\d+)(?!\S)/);
    var n = m ? parseInt(m[1], 10) : 1;
    return n > 0 && n < 100000 ? n : 1;
  }

  /* Không dùng \b vì JS coi chữ có dấu là ký tự ngoài từ */
  var PROMO = /(^|[\s,.\-])(freeship|free ship|giá rẻ|giá sỉ|hàng chính hãng|chính hãng|sẵn hàng|hàng có sẵn|bảo hành|ship nhanh|siêu rẻ|loại tốt|chất lượng cao|mới|new)(?=$|[\s,.\-])/gi;
  function cleanName(name) {
    return String(name || "")
      .replace(/[\[【〔][^\]】〕]*[\]】〕]/g, " ")
      .replace(PROMO, "$1")
      .replace(/[|•★☆✅🔥⚡]+/g, " ")
      .replace(/\(\s+/g, "(").replace(/\s+\)/g, ")")
      .replace(/\s*[-–,]\s*$/, "")
      .replace(/\s{2,}/g, " ")
      .trim();
  }

  function absUrl(href) {
    try { return new URL(href, location.origin).href.split("?")[0]; } catch (e) { return ""; }
  }

  /* Vị trí dòng "Xem Shop" (Shopee lúc viết hoa lúc không) */
  function indexOfXemShop(ls) {
    for (var i = 0; i < ls.length; i++) { if (/^xem shop$/i.test(ls[i])) { return i; } }
    return -1;
  }
  function indexOfChat(ls) {
    for (var i = 0; i < ls.length; i++) { if (/^chat( ngay)?$/i.test(ls[i])) { return i; } }
    return -1;
  }

  function isProductHref(href) { return /-i\.\d+\.\d+/.test(href || "") || /\/product\/\d+\/\d+/.test(href || ""); }

  /* ---------- Đơn mua / chi tiết đơn ---------- */

  /* Phần tử chứa đúng 1 dòng chữ thoả [re] */
  function textElements(root, re) {
    var res = [];
    var all = root.querySelectorAll("div, span, p, label, a, button");
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      if (el.children.length === 0 && re.test((el.textContent || "").trim())) { res.push(el); }
    }
    return res;
  }

  /* Leo lên tới tổ tiên gần nhất thoả [test] (tối đa [max] cấp) */
  function climb(el, test, max) {
    for (var i = 0; el && i < (max || 30); i++, el = el.parentElement) {
      if (test(el)) { return el; }
    }
    return null;
  }

  function scrapeOrders(root) {
    var pageLines = lines(root);
    /* Trang chi tiết: "MÃ ĐƠN HÀNG. xxx | Trạng thái" */
    var detailStatus = "";
    var codeIdx = pageLines.findIndex(function (l) { return /^MÃ ĐƠN HÀNG/i.test(l); });
    if (codeIdx >= 0 && pageLines[codeIdx + 1] === "|") { detailStatus = pageLines[codeIdx + 2] || ""; }

    var items = [];
    var seenRows = [];
    textElements(root, QTY).forEach(function (qtyEl) {
      /* Dòng sản phẩm: tổ tiên gần nhất có ảnh + giá */
      var row = climb(qtyEl, function (el) {
        return el.querySelector && el.querySelector("img") && lines(el).some(function (l) { return PRICE.test(l); });
      }, 8);
      if (!row || seenRows.indexOf(row) >= 0) { return; }
      seenRows.push(row);
      var rl = lines(row);
      var qty = parseInt(qtyEl.textContent.replace(/\D/g, ""), 10) || 1;
      var model = "";
      var name = "";
      rl.forEach(function (l) {
        var m = l.match(/^Phân loại hàng:\s*(.*)$/i);
        if (m) { model = m[1].trim(); return; }
        if (!name && !QTY.test(l) && !PRICE.test(l)) { name = l; }
      });
      var prices = rl.filter(function (l) { return PRICE.test(l); });
      /* Giá gạch ngang đứng trước, giá thật đứng sau */
      var price = prices.length ? parsePrice(prices[prices.length - 1]) : 0;

      var link = "";
      var a = row.closest("a[href]") || row.querySelector("a[href]");
      if (a && isProductHref(a.getAttribute("href"))) { link = absUrl(a.getAttribute("href")); }

      /* Khung đơn: tổ tiên gần nhất có nút "Xem Shop" */
      var card = climb(row, function (el) { return indexOfXemShop(lines(el)) >= 0; }, 25);
      var shop = "";
      var status = detailStatus;
      if (card) {
        var cl = lines(card);
        var chat = indexOfChat(cl);
        var xem = indexOfXemShop(cl);
        if (chat > 0) { shop = cl[chat - 1]; } else if (xem > 0) { shop = cl[xem - 1]; }
        /* Trạng thái: dòng cuối giữa "Xem Shop" và sản phẩm đầu tiên */
        var first = cl.indexOf(rl[0]);
        if (xem >= 0 && first > xem + 1) { status = cl[first - 1]; }
      }
      items.push({ rawName: name, model: model, attrs: "", qty: qty, price: price, shop: shop, status: status, link: link });
    });
    return items;
  }

  function isCancelled(status) {
    return /đã hủy|đã huỷ|hủy bởi|huỷ bởi|trả hàng thành công|đã hoàn tiền/i.test(String(status || ""));
  }

  /* ---------- Trang sản phẩm ---------- */

  /* Nhóm phân loại: section có h2 + các nút chọn (aria-label) */
  function variationGroups(root) {
    var groups = [];
    var sections = root.querySelectorAll("section");
    for (var i = 0; i < sections.length; i++) {
      var s = sections[i];
      var h = s.querySelector("h2, h3, label");
      var buttons = s.querySelectorAll("button[aria-label]");
      var opts = [];
      for (var j = 0; j < buttons.length; j++) {
        var b = buttons[j];
        /* Section lồng nhau: nút chỉ thuộc section gần nhất */
        if (b.closest("section") !== s) { continue; }
        if (/selection-box|product-variation/.test(b.className || "") || b.getAttribute("aria-disabled") !== null) {
          var label = (b.getAttribute("aria-label") || "").trim();
          if (label && !/^(increase|decrease)$/i.test(label)) { opts.push(label); }
        }
      }
      if (h && opts.length) { groups.push({ name: h.textContent.trim(), options: opts, section: i }); }
    }
    return groups;
  }

  function optionButton(root, group, label) {
    var s = root.querySelectorAll("section")[group.section];
    if (!s) { return null; }
    var buttons = s.querySelectorAll("button[aria-label]");
    for (var i = 0; i < buttons.length; i++) {
      if ((buttons[i].getAttribute("aria-label") || "").trim() === label) { return buttons[i]; }
    }
    return null;
  }

  function isSelected(b) { return /selection-box-selected|--selected/.test(b.className || "") || b.getAttribute("aria-pressed") === "true"; }

  function currentPrice(root) {
    var live = root.querySelector('section[aria-live="polite"]');
    var ls = lines(live || root).filter(function (l) { return /₫/.test(l); });
    if (!ls.length) { return { price: 0, range: false }; }
    var first = ls[0];
    return { price: parsePrice(first), range: /₫\s*[-–]\s*₫?[\d.]/.test(first) || (ls.length > 1 && /^[-–]$/.test(ls[1])) };
  }

  /* Nhóm giống "quy cách gói" (để vào cột Phân loại) hay thuộc tính biến thể */
  function looksLikePack(group) {
    if (/gói|số lượng|combo|set|bộ|túi|bịch|hộp|cặp|pack|qty/i.test(group.name)) { return true; }
    return group.options.every(function (o) { return guessUnits(o) > 1; });
  }

  function cleanValue(v) { return String(v).replace(/\(\s+/g, "(").replace(/\s+\)/g, ")").replace(/\s{2,}/g, " ").trim(); }

  function combos(groups, max) {
    var res = [[]];
    groups.forEach(function (g) {
      var next = [];
      res.forEach(function (c) { g.options.forEach(function (o) { if (next.length < max) { next.push(c.concat([o])); } }); });
      res = next;
    });
    return res;
  }

  function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

  function productInfo(root) {
    var h1 = root.querySelector("h1");
    var shop = "";
    var xem = textElements(root, /^xem shop$/i)[0];
    if (xem) {
      /* Khối người bán: tên shop, "online", "Chat ngay", "xem shop" */
      var box = climb(xem, function (el) { return lines(el).length >= 3; }, 6);
      var bl = box ? lines(box) : [];
      shop = bl.filter(function (l) { return !/^(xem shop|chat ngay|chat|online|yêu thích\+?|mall)$/i.test(l) && !/hoạt động/i.test(l); })[0] || "";
    }
    shop = cleanValue(shop);
    return { name: h1 ? h1.textContent.trim() : document.title.replace(/\s*\|\s*Shopee.*$/i, ""), shop: shop, link: absUrl(location.href) };
  }

  /* Bấm lần lượt từng tổ hợp phân loại để đọc giá */
  function scrapeProduct(root, onProgress, readPrices) {
    var info = productInfo(root);
    var groups = variationGroups(root);
    var all = combos(groups, 60);
    var packGroups = groups.map(looksLikePack);
    function row(combo, price) {
      var attrs = [];
      var pack = [];
      combo.forEach(function (o, i) {
        if (packGroups[i]) { pack.push(cleanValue(o)); } else { attrs.push(groups[i].name + "=" + cleanValue(o)); }
      });
      return { rawName: info.name, model: pack.join(" · "), attrs: attrs.join("; "), qty: 0, price: price, shop: info.shop, status: "", link: info.link };
    }
    if (!groups.length || !readPrices) {
      var p = currentPrice(root).price;
      return Promise.resolve(groups.length ? all.map(function (c) { return row(c, p); }) : [row([], p)]);
    }
    var out = [];
    var i = 0;
    function next() {
      if (i >= all.length) { return Promise.resolve(out); }
      var combo = all[i++];
      onProgress(i, all.length);
      var disabled = false;
      combo.forEach(function (label, gi) {
        var b = optionButton(root, groups[gi], label);
        if (!b || b.getAttribute("aria-disabled") === "true") { disabled = true; return; }
        if (!isSelected(b)) { b.click(); }
      });
      return sleep(disabled ? 0 : 350).then(function () {
        var cp = currentPrice(root);
        var r = row(combo, disabled || cp.range ? 0 : cp.price);
        r.unavailable = disabled;
        out.push(r);
        return next();
      });
    }
    return next();
  }

  /* ---------- Gộp, xuất ---------- */

  /* Gộp trùng (cùng tên + phân loại + thuộc tính + shop): cộng số lượng, giữ
   * giá gặp đầu tiên (đơn mới nhất ở trên cùng) */
  function merge(items, skipCancelled) {
    var map = {};
    var order = [];
    items.forEach(function (it) {
      if (skipCancelled && isCancelled(it.status)) { return; }
      var key = [it.rawName, it.model, it.attrs, it.shop].join("\u0001");
      if (map[key]) {
        map[key].qty += it.qty;
        if (!map[key].link && it.link) { map[key].link = it.link; }
        return;
      }
      var units = guessUnits(it.model);
      var row = {
        include: !it.unavailable,
        rawName: it.rawName,
        name: cleanName(it.rawName) || it.rawName,
        attrs: it.attrs || "",
        model: it.model,
        units: units > 1 ? units : guessUnits(it.rawName),
        price: it.price,
        qty: it.qty,
        shop: it.shop,
        link: it.link
      };
      map[key] = row;
      order.push(row);
    });
    return order;
  }

  function toRecords(rows) {
    return rows.filter(function (r) { return r.include; }).map(function (r) {
      return {
        "Tên linh kiện": r.name,
        "Thuộc tính": r.attrs,
        "Phân loại": r.model,
        "Số cái/gói": r.units,
        "Giá gói": r.price,
        "Số lượng mua": r.qty,
        "Shop": r.shop,
        "Link": r.link
      };
    });
  }

  function toCsv(records) {
    if (!records.length) { return ""; }
    var cols = Object.keys(records[0]);
    function esc(v) {
      var s = String(v == null ? "" : v);
      return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
    }
    return [cols.map(esc).join(",")].concat(records.map(function (r) {
      return cols.map(function (c) { return esc(r[c]); }).join(",");
    })).join("\r\n");
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) { return navigator.clipboard.writeText(text); }
    var ta = doc.createElement("textarea");
    ta.value = text;
    doc.body.appendChild(ta);
    ta.select();
    doc.execCommand("copy");
    ta.remove();
    return Promise.resolve();
  }

  /* Cho phép test bằng Node + jsdom: chỉ xuất hàm, không dựng giao diện */
  if (window.__ccShopeeTest) {
    window.__ccShopeeTest({
      scrapeOrders: scrapeOrders, scrapeProduct: scrapeProduct, variationGroups: variationGroups,
      productInfo: productInfo, merge: merge, toRecords: toRecords, guessUnits: guessUnits,
      cleanName: cleanName, isCancelled: isCancelled, looksLikePack: looksLikePack
    });
    return;
  }

  if (!/(^|\.)shopee\.vn$/.test(location.hostname)) {
    alert("Hãy mở shopee.vn: trang Đơn mua, chi tiết đơn hàng hoặc trang sản phẩm rồi bấm lại bookmark.");
    return;
  }
  var old = doc.getElementById(ID);
  if (old) { old.remove(); }

  /* ---------- Giao diện ---------- */
  var isProduct = !/\/user\/purchase/.test(location.pathname);

  function el(tag, attrs, children) {
    var e = doc.createElement(tag);
    for (var k in (attrs || {})) {
      if (k === "style") { e.style.cssText = attrs[k]; }
      else if (k.indexOf("on") === 0) { e.addEventListener(k.slice(2), attrs[k]); }
      else { e[k] = attrs[k]; }
    }
    (children || []).forEach(function (c) { e.append(c); });
    return e;
  }

  var BTN = "padding:6px 12px;border-radius:8px;border:1px solid #d0d5dd;background:#fff;color:#222;cursor:pointer;font:inherit;";
  var BTN_PRIMARY = "padding:6px 12px;border-radius:8px;border:none;background:#ee4d2d;color:#fff;cursor:pointer;font:inherit;font-weight:600;";
  var INPUT = "width:100%;box-sizing:border-box;padding:3px 6px;border:1px solid #d0d5dd;border-radius:6px;font:inherit;color:#222;background:#fff;";

  var rows = [];
  var rawItems = [];
  var status = el("div", { style: "color:#555;margin:8px 0;" }, [""]);
  var skipCancel = el("input", { type: "checkbox", checked: true });
  var tableBox = el("div", { style: "flex:1;overflow:auto;border:1px solid #eee;border-radius:8px;" });

  function render() {
    tableBox.innerHTML = "";
    if (!rows.length) { return; }
    var cols = ["", "Tên linh kiện", "Thuộc tính (Tên=Giá trị; ...)", "Phân loại", "Cái/gói", "Giá gói", "SL mua", "Shop"];
    var head = el("tr", {}, cols.map(function (h) {
      return el("th", { style: "position:sticky;top:0;background:#fafafa;text-align:left;padding:6px;border-bottom:1px solid #eee;font-weight:600;" }, [h]);
    }));
    var body = rows.map(function (r) {
      function cell(input) { return el("td", { style: "padding:4px 6px;border-bottom:1px solid #f2f2f2;vertical-align:top;" }, [input]); }
      function edit(field, type, width) {
        return el("input", {
          type: type, value: r[field], style: INPUT + (width ? "width:" + width + "px;" : ""),
          oninput: function (e) { r[field] = type === "number" ? Number(e.target.value) : e.target.value; }
        });
      }
      var name = edit("name", "text");
      name.title = r.rawName;
      return el("tr", { style: r.include ? "" : "opacity:.45;" }, [
        cell(el("input", { type: "checkbox", checked: r.include, onchange: function (e) { r.include = e.target.checked; render(); } })),
        cell(name),
        cell(edit("attrs", "text")),
        cell(edit("model", "text")),
        cell(edit("units", "number", 70)),
        cell(edit("price", "number", 90)),
        cell(edit("qty", "number", 60)),
        cell(edit("shop", "text", 140))
      ]);
    });
    tableBox.append(el("table", { style: "width:100%;border-collapse:collapse;" }, [el("thead", {}, [head]), el("tbody", {}, body)]));
    var n = rows.filter(function (r) { return r.include; }).length;
    status.textContent = "Đã chọn " + n + "/" + rows.length + " dòng. Rê chuột vào tên để xem tên gốc. Có thể sửa mọi ô trước khi sao chép.";
  }

  function rebuild() { rows = merge(rawItems, skipCancel.checked); render(); }

  function readOrders() {
    rawItems = scrapeOrders(doc.body);
    if (!rawItems.length) {
      status.textContent = "Không thấy sản phẩm nào trên trang. Hãy mở tab Đơn mua (hoặc chi tiết đơn) và chờ trang tải xong.";
      tableBox.innerHTML = "";
      return;
    }
    rebuild();
  }

  /* Đơn mua tải thêm khi cuộn: cuộn xuống tới khi không còn đơn mới */
  function loadMore() {
    var before = scrapeOrders(doc.body).length;
    var tries = 0;
    var stable = 0;
    status.textContent = "Đang cuộn để tải thêm đơn...";
    function step() {
      window.scrollTo(0, doc.body.scrollHeight);
      return sleep(1200).then(function () {
        var now = scrapeOrders(doc.body).length;
        stable = now === before ? stable + 1 : 0;
        before = now;
        tries++;
        status.textContent = "Đang cuộn... " + now + " sản phẩm";
        if (stable < 2 && tries < 40) { return step(); }
        readOrders();
      });
    }
    step();
  }

  function readProduct(withPrices) {
    status.textContent = withPrices ? "Đang bấm từng phân loại để đọc giá..." : "Đang đọc...";
    scrapeProduct(doc.body, function (i, n) { status.textContent = "Đang đọc giá " + i + "/" + n + "..."; }, withPrices)
      .then(function (items) { rawItems = items; rebuild(); })
      .catch(function (e) { status.textContent = "Lỗi: " + e.message; });
  }

  function exportJson() {
    var records = toRecords(rows);
    if (!records.length) { alert("Chưa chọn dòng nào"); return; }
    copyText(JSON.stringify(records, null, 1)).then(function () {
      status.textContent = "Đã sao chép " + records.length + " dòng. Mở app > Dữ liệu > \"Dán từ clipboard\".";
    }, function (e) { alert("Không sao chép được: " + e); });
  }

  function exportCsv() {
    var records = toRecords(rows);
    if (!records.length) { alert("Chưa chọn dòng nào"); return; }
    var blob = new Blob(["﻿" + toCsv(records)], { type: "text/csv;charset=utf-8" });
    var a = el("a", { href: URL.createObjectURL(blob), download: "shopee-linh-kien.csv" });
    doc.body.appendChild(a);
    a.click();
    a.remove();
  }

  var actions = isProduct ? [
    el("button", { style: BTN_PRIMARY, onclick: function () { readProduct(true); } }, ["Đọc giá từng phân loại"]),
    el("button", { style: BTN, onclick: function () { readProduct(false); } }, ["Chỉ lấy giá đang hiện"])
  ] : [
    el("label", { style: "display:flex;align-items:center;gap:4px;" }, [skipCancel, "Bỏ đơn đã huỷ"]),
    el("button", { style: BTN_PRIMARY, onclick: readOrders }, ["Đọc lại trang"]),
    el("button", { style: BTN, onclick: loadMore }, ["Cuộn tải thêm đơn"])
  ];

  var panel = el("div", {
    id: ID,
    style: "position:fixed;inset:24px;z-index:2147483647;background:#fff;color:#222;border-radius:14px;box-shadow:0 10px 40px rgba(0,0,0,.35);padding:16px;display:flex;flex-direction:column;font:13px/1.4 system-ui,sans-serif;"
  }, [
    el("div", { style: "display:flex;align-items:center;gap:8px;flex-wrap:wrap;" }, [
      el("b", { style: "font-size:16px;margin-right:auto;" }, [isProduct ? "Component Companion · Lấy sản phẩm" : "Component Companion · Lấy linh kiện từ đơn mua"])
    ].concat(actions).concat([
      el("button", { style: BTN, onclick: function () { var all = rows.every(function (x) { return x.include; }); rows.forEach(function (r) { r.include = !all; }); render(); } }, ["Chọn / bỏ tất cả"]),
      el("button", { style: BTN_PRIMARY, onclick: exportJson }, ["Sao chép cho app"]),
      el("button", { style: BTN, onclick: exportCsv }, ["Tải CSV"]),
      el("button", { style: BTN, onclick: function () { panel.remove(); } }, ["Đóng"])
    ])),
    status,
    tableBox
  ]);
  skipCancel.addEventListener("change", function () { if (rawItems.length) { rebuild(); } });
  doc.body.appendChild(panel);

  if (isProduct) {
    var groups = variationGroups(doc.body);
    status.textContent = groups.length
      ? "Sản phẩm có " + groups.length + " nhóm phân loại. Bấm \"Đọc giá từng phân loại\" (trang sẽ tự chọn từng tổ hợp)."
      : "Sản phẩm không có phân loại.";
    if (!groups.length) { readProduct(false); }
  } else {
    readOrders();
  }
})();
