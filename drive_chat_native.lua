--=================================================================
-- DRIVE CHAT — النسخة الـ Native (drive_chat_native.lua)
--=================================================================
-- ملف Lua منفصل تماماً عن player_menu.lua (يُنشر كـ SCRIPT_X ثاني بمفرده).
-- سبب وجوده: متصفح CSP المدمج (WebBrowser/CEF) يحتاج وصول لملفات ذاكرة
-- مشتركة (shared memory) وهذا الوصول ممنوع على سكربتات "Server Script"
-- (اللي تُحمَّل من السيرفر) — القيد موثّق رسمياً هنا:
--   https://github.com/ac-custom-shaders-patch/acc-lua-sdk/wiki/Important-notes
-- ولا يوجد أي تعديل حديث بـ CSP يلغي هذا القيد. فبدل الشات-عبر-متصفح-HTML
-- صرنا نرسم الشات بالكامل بأدوات ImGui الأصلية اللي CSP يعرضها لكل أنواع
-- السكربتات بدون استثناء (ui.* / ac.*) — نفس فكرة رسم فقاعات الإشعارات اللي
-- كانت أصلاً native في النسخة القديمة.
--
-- الشبكة/الباك-إند لم يتغيّر إطلاقاً عن player_menu.lua القديم:
--   • الشات العام:  ac.sendChatMessage()  /  ac.onChatMessage()  (بروتوكول AC الأصلي)
--   • شات الكلان + الخاص + الرتب + اللايكات + الوصف + الربط:  REST عبر web.get/web.post لبوت RANKS_URL
--   • تواصل مع الإدارة + سجل الشات:  Discord Webhooks عبر web.post
-- كل هذا مستقل 100% عن أي متصفح — فقط طبقة العرض تغيّرت.
--
-- ⚠️ ملاحظة اختبار: لا يوجد لدي بيئة AC/CSP فعلية لتشغيل هذا الملف بصرياً.
-- تم التحقق فقط من: صحة الصياغة (luac -p) + تشغيل تمهيدي عبر harness محاكي
-- لواجهات ac.*/ui.* (لا يغطي كل مسار تفاعل مستخدم فعلي). يحتاج اختبار حقيقي
-- داخل اللعبة قبل الاعتماد عليه الكامل.
--=================================================================

local __ok, __err = pcall(function()

--=================================================================
-- [1] الإعدادات
--=================================================================
local ADMIN_WEBHOOK   = "https://discord.com/api/webhooks/1536077079446294588/EXaBQ2dv9hJwU8EHRNDxCM6VJZHL42XQfGq9ytBjKefZzhxHCds_DqHMn7LgMED3IESH"
local CHATLOG_WEBHOOK = "https://discord.com/api/webhooks/1536076922402902087/rNy5tdYAdkRS7baBkKu0sb56nowE5TfpueIG2JgitqBF9_z7vNXbpUcsVCq7uwsauVQ_"
local RANKS_URL       = "http://91.218.66.157:3050/drive/ranks"
local ADMIN_NAMES     = {}

local KEY = string.byte("C")

local ACC  = rgbm(1.00, 0.45, 0.06, 1)
local CY   = rgbm(1.00, 0.84, 0.20, 1)
local CW   = rgbm.colors.white
local CDm  = rgbm(0.66, 0.67, 0.70, 1)
local FONT = "Segoe UI;Weight=Bold"
local NOOP = function() end

local cStor = ac.storage{ dc_notif = true, dc_posX = -1, dc_posY = -1, dc_logX = 16, dc_logY = -1 }

local CHAT_W, CHAT_H = 980, 660
local LOG_MAX = 60

--=================================================================
-- [2] الستيكرز / الإيموجي / الجمل الجاهزة
--=================================================================
-- ملاحظة: شلنا تبويب الـ GIF المتحرك من المنتقي عمداً — عارض الصور الأصلي
-- بـ CSP (ui.decodeImage/ui.drawImage) يعرض صور ثابتة (JPG/PNG) بس، ما يشغّل
-- GIF متحرك (هذا يحتاج متصفح CEF حقيقي زي ما تسوي سيرفرات ثانية، وإحنا تركنا
-- ذاك الخيار بالتصميم من البداية عشان قيود CSP على الـ Server Scripts). فبدل
-- ما يطلع مربع رمادي ميت دايماً كنا نخفيه بدل ما نسيبه "مكسور".
local STICKERS = {
  "https://pbs.twimg.com/media/G7gyUn4WMAAafxA.jpg",
  "https://i1.sndcdn.com/artworks-kpz9WCWcGJ9AFL58-10R0yA-t500x500.jpg",
  "https://i.pinimg.com/236x/9c/b9/17/9cb917337ebedb3dda74c974bde47dc0.jpg",
  "https://i.ytimg.com/vi/h5f9rl2Y5F8/oar2.jpg",
  "https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEibrYm5kiGVQRHXjNHVTJg1U8X97tUKCHc5K2r2rA4_J0xo8ALquNxqJK3VMxbI0N6mlcw_XguUtshae1huBmBNNe8cwh6_YyU9cVcZYa3_xtf8GnO2odL2vzqcWp31WjuCbkGL4r8BT1AufOl99KqxR27ITeULa6749SXfQFGFzJ3iW7udeFXz9ifywA/s640/IMG_20220925_202534_772.jpg",
  "https://i.imgur.com/9uijEsa.png",
  "https://pbs.twimg.com/media/HEOexNwWkAArXOi.jpg",
  "https://i.imgur.com/4wYJO7H.png",
  "https://i.imgur.com/GvkKdq6.png",
  "https://pbs.twimg.com/media/EoeGhb_W4AA9C4k.jpg",
  "https://pbs.twimg.com/media/EuXWokjXYAADh8S.jpg",
  "https://pbs.twimg.com/media/EsJHirnWMAQL1Ms.jpg",
  "https://i.imgur.com/2mcsEo7.png",
  "https://i.imgur.com/2mcsEo7.png",
  "https://encrypted-tbn0.gstatic.com/images?q=tbn%3AANd9GcSFzD9EzBhZxb2sWSCuS2tLgObdTqGoZSgUMHShhQbkiA&shttps%3A%2F%2Fencrypted-tbn0.gstatic.com%2Fimages%3Fq=tbn%3AANd9GcSFzD9EzBhZxb2sWSCuS2tLgObdTqGoZSgUMHShhQbkiA&s=",
  "https://encrypted-tbn0.gstatic.com/images?q=tbn%3AANd9GcQ54uKUXaNz07fJcjT7r9NlIbfGSiUWYtMwnI7d-vfM3gLKD1TuCXjMVd4&s=10",
}
local ALLPICS, PICIDX = {}, {}
for _, u in ipairs(STICKERS) do ALLPICS[#ALLPICS + 1] = u end
for i, u in ipairs(ALLPICS)  do PICIDX[u] = i end

local EMOJIS = {
  "😀","😁","😂","🤣","😊","😍","😎","😭","😡","👍","👎","🙏","🔥","💯","🎉","👑","🏁","🚗","💨","⚡",
  "❤️","🧡","💛","💚","💙","💜","🤍","🖤","😴","🤔","😏","😜","🥳","😱","🤯","🫡","🤝","✌️","🤙","👀",
  "💪","🙌","😅","😬","🥶","🤗","😇","🤪","😤","🫠",
}
local PHRASES = { "سلام عليكم","وعليكم السلام","مدارس","عداك العيب","كفوووو","ولا شيء يا كنق","لعيونك","لعيونكم" }
local CLAN_COLOR_PRESETS = { "#F7820E", "#E5484D", "#3B82F6", "#12B886", "#8757D4" }
local CLAN_EMOJIS_ALL = {
  "🛡️","⚔️","🔥","⚡","🎯","🏁","🐺","🦅","🦁","🐉","🐍","🦈","🚀","☠️","🌪️",
  "❄️","🧨","🎲","🦂","🐻","🦖","🎖️","🀄","🌟","⭐","🔱","💠","👑","💎","🏆",
}
local RANK_LABEL = { admin = "ADMIN", mod = "MOD", vip = "VIP" }
local CLAN_REASONS = {
  bad_args="بيانات ناقصة", not_linked="اربط حسابك أول", already_in_clan="أنت في كلان بالفعل",
  no_permission="ما عندك صلاحية إنشاء كلان", bad_name="اسم غير صالح (2-20)", bad_tag="تاق غير صالح (2-5)",
  name_taken="الاسم محجوز", not_in_clan="ما عندك كلان", not_owner="المالك فقط يقدر",
  target_not_linked="اللاعب غير مربوط", target_has_clan="اللاعب عنده كلان", full="الكلان ممتلئ",
  already_invited="تمت دعوته من قبل", no_invite="لا توجد دعوة", not_member="ليس عضواً",
  cant_kick_self="ما تقدر تطرد نفسك", owner_must_transfer="انقل الملكية أول",
  target_not_member="ليس عضواً في كلانك", no_clan="الكلان غير موجود", color_locked="اللون الحر يُفتح بمستوى 8",
  emoji_locked="هذا الإيموجي يُفتح بمستوى أعلى", cant_kick_leader="ما تقدر تطرد قائد",
  already_coleader="هو أصلاً قائد مساعد", not_coleader="ليس قائد مساعد",
}

--=================================================================
-- [3] الحالة
--=================================================================
local S = {
  clock = 0,
  open = false, wantsKbd = false,
  pos = nil, W = CHAT_W, H = CHAT_H, dragging = false, dragOff = vec2(0, 0), prevKey = false,
  overlayOpen = false,

  -- الشات العام
  log = {}, msgId = 0,
  msgInput = "", wantFocusInput = false,

  -- الأعضاء
  members = {}, memberSearch = "", joined = {}, lastPush = -999,
  ranks = {}, lastRanks = -999,

  -- القنوات (عام/كلان/خاص)
  activeChannel = "general",
  clanLog = {}, clanMaxId = 0, clanSeen = {},
  dmConvs = {}, dmMsgs = {}, dmLastId = {}, dmSeen = {}, activeDmWith = nil,
  lastMsgPoll = -999,
  dmSearch = "",

  -- منتقي الملصقات/الإيموجي
  activePicker = nil, -- nil | 'emoji' | 'stick' | 'gif' | 'phr'

  -- فقاعات الإشعارات (نفس النمط القديم)
  chatReveal = 1, logDrag = false, logDragStart = vec2(0, 0), logOfsStart = vec2(0, 0),

  -- بروفايل
  profileOpen = false, profileName = nil, descInput = "", descLoadedFor = nil,

  -- تواصل مع الإدارة
  adminOpen = false, adminText = "",

  -- محادثة جديدة (DM)
  newConvOpen = false, newConvSearch = "",

  -- الكلانات
  clanOpen = false, clanScreen = "main", clanView = nil, clanLoadToken = 0,
  myClan = nil, myClanLoaded = false, isOwner = false, isCoLeader = false,
  invites = {}, canCreate = true,
  clanEmojisTaken = {}, clanEmojiSlots = 6, clanEmojiPerRow = 6,
  clanPickEmoji = "🛡️", clanPickColor = "#F7820E", clanPickHue = 30,
  clanCreateName = "", clanCreateTag = "",
  clanEditDesc = "",
  clanInviteSearch = "",
  clanConfirm = nil, -- { msg=, action=function() end }

  -- توست
  toastText = nil, toastUntil = 0,
}

--=================================================================
-- [4] أدوات مساعدة عامة
--=================================================================
local function myName() return ac.getDriverName(0) or "أنت" end
local function rankOf(nm)
  local r = S.ranks[nm]
  return (r and r.rank) or ADMIN_NAMES[nm] or ""
end
local function jsonStr(s)
  if not s then return '""' end
  return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '') .. '"'
end
local function urlEncode(s)
  s = tostring(s or "")
  return (s:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local function inRect2(p, a, b)
  return p.x >= a.x and p.y >= a.y and p.x <= b.x and p.y <= b.y
end
local function nowHM()
  return os.date("%H:%M")
end
local function toast(t)
  S.toastText = t
  S.toastUntil = S.clock + 2.5
end
local function isLinked(name)
  if not name or name == "" then return false end
  local r = S.ranks[name]
  return r ~= nil and r.discord ~= nil and r.discord ~= false
end
local function memberByName(nm)
  for _, m in ipairs(S.members) do if m.name == nm then return m end end
  return nil
end

--=================================================================
-- [5] السجل + الرسائل الصادرة مني (الشات العام)
--=================================================================
local function pushLog(m)
  S.msgId = S.msgId + 1
  m.id = S.msgId
  S.log[#S.log + 1] = m
  while #S.log > LOG_MAX do table.remove(S.log, 1) end
  S.newGeneral = true
end
local function ownMsg(text, sticker)
  pushLog({ name = myName(), text = text, sticker = sticker, srv = false, mine = true, t = S.clock })
end
local function sysMsg(t)
  pushLog({ name = "DRIVE", text = t, srv = true, t = S.clock })
end
-- رسالة خاصة تُعرض على شاشتي فقط ولا تُخزَّن أبداً (كود /link وأمثاله) — توست بدل فقاعة دائمة
local function privMsg(t) toast(t) end

--=================================================================
-- [6] الويب هوك (سجل الشات + تواصل مع الإدارة)
--=================================================================
local function relayChatLog(txt)
  if CHATLOG_WEBHOOK == "" then return end
  pcall(function()
    local body = '{"content":' .. jsonStr("**" .. myName() .. "**: " .. txt) .. '}'
    web.post(CHATLOG_WEBHOOK, { ['Content-Type'] = 'application/json' }, body, NOOP)
  end)
end
local function sendAdminMsg(txt)
  if ADMIN_WEBHOOK == "" then toast("التواصل مع الإدارة غير مفعّل حالياً"); return end
  local nm = myName()
  local r = S.ranks[nm]
  local dstat = "Not linked"
  if r and r.discord then dstat = (type(r.discord) == 'string') and r.discord or "Linked" end
  local payload = '{"embeds":[{"title":"\\ud83d\\udce8 Contact Admin","color":16744576,"fields":['
    .. '{"name":"Player","value":' .. jsonStr(nm) .. ',"inline":true},'
    .. '{"name":"Discord","value":' .. jsonStr(dstat) .. ',"inline":true},'
    .. '{"name":"Message","value":' .. jsonStr(txt) .. ',"inline":false}'
    .. '],"footer":{"text":"DRIVE CHAT"},"timestamp":"' .. os.date('!%Y-%m-%dT%H:%M:%SZ') .. '"}]}'
  web.post(ADMIN_WEBHOOK, { ['Content-Type'] = 'application/json' }, payload, function(err)
    if err then toast("تعذر الإرسال — كلم الإدارة بالديسكورد")
    else toast("تم إرسال رسالتك للإدارة ✓") end
  end)
end

--=================================================================
-- [7] الرتب / الربط / اللايك / الوصف
--=================================================================
local function fetchRanks()
  if RANKS_URL == "" then return end
  pcall(function()
    web.get(RANKS_URL, function(err, resp)
      if err or not resp or not resp.body then return end
      local ok, data = pcall(function() return JSON.parse(resp.body) end)
      if ok and type(data) == 'table' and type(data.players) == 'table' then
        S.ranks = data.players
      end
    end)
  end)
end
local function sendLike(targetName)
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local body = '{"likerName":' .. jsonStr(myName()) .. ',"targetName":' .. jsonStr(targetName) .. '}'
  pcall(function()
    web.post(base .. '/drive/like', { ['Content-Type'] = 'application/json' }, body, function(err, resp)
      local ok, likes, reason = false, nil, nil
      if not err and resp and resp.body then
        pcall(function()
          local d = JSON.parse(resp.body)
          ok = d and d.ok; likes = d and d.likes; reason = d and d.reason
        end)
      end
      if ok then
        toast("تم اللايك 👍 (المجموع: " .. tostring(likes or 0) .. ")")
      elseif reason == 'already' then toast("سبق وسويت لايك لهذا اللاعب")
      elseif reason == 'self' then toast("ما تقدر تسوي لايك لنفسك")
      elseif reason == 'liker_not_linked' then toast("اربط حسابك أول (/link) عشان تسوي لايك")
      elseif reason == 'target_not_linked' then toast("هذا اللاعب غير مربوط بالديسكورد")
      else toast("تعذّر تسجيل اللايك") end
    end)
  end)
end
local function sendDescription(txt)
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local body = '{"name":' .. jsonStr(myName()) .. ',"desc":' .. jsonStr(txt) .. '}'
  pcall(function()
    web.post(base .. '/drive/description', { ['Content-Type'] = 'application/json' }, body, function(err, resp)
      local ok, desc, hasDesc = false, "", false
      if not err and resp and resp.body then
        pcall(function()
          local d = JSON.parse(resp.body)
          ok = d and d.ok
          if d and d.desc ~= nil then desc = d.desc; hasDesc = true end
        end)
      end
      if ok then
        toast("تم حفظ الوصف ✓")
        local me = memberByName(myName())
        if me and hasDesc then me.desc = desc end
        S.lastRanks = 0
      else
        toast("تعذّر حفظ الوصف — اربط حسابك أول")
      end
    end)
  end)
end
local function startDiscordLink()
  if RANKS_URL == "" then privMsg("نظام الربط غير مفعّل حالياً — كلم الإدارة"); return end
  privMsg("⏳ جاري طلب كود الربط...")
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local code = tostring(math.random(100000, 999999))
  local steam = ""
  pcall(function() steam = ac.getUserSteamID() or "" end)
  local body = '{"name":' .. jsonStr(myName()) .. ',"steam":' .. jsonStr(steam) .. ',"code":' .. jsonStr(code) .. '}'
  pcall(function()
    web.post(base .. '/drive/linkcode', { ['Content-Type'] = 'application/json' }, body, function(err)
      if err then
        privMsg("⚠️ تعذر الاتصال بنظام الربط — حاول بعد شوي")
      else
        privMsg("🔗 كود الربط حقك (خاص لك فقط): " .. code)
        privMsg("ارسله بالخاص لبوت الديسكورد (يكفي الكود لحاله)، أو بأي روم: !verify " .. code)
        privMsg("صالح ١٠ دقايق — لا تعطيه أحد.")
      end
    end)
  end)
end

--=================================================================
-- [8] جسر الكلانات (REST)
--=================================================================
local clanFetchMine -- forward
local function clanPost(endpoint, extra, okMsg)
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local obj = extra or {}
  obj.name = myName()
  local parts = {}
  for k, v in pairs(obj) do
    if type(v) == 'boolean' then
      parts[#parts+1] = jsonStr(k) .. ':' .. (v and 'true' or 'false')
    else
      parts[#parts+1] = jsonStr(k) .. ':' .. jsonStr(tostring(v))
    end
  end
  local body = '{' .. table.concat(parts, ',') .. '}'
  pcall(function()
    web.post(base .. endpoint, { ['Content-Type'] = 'application/json' }, body, function(err, resp)
      local ok, reason = false, nil
      if not err and resp and resp.body then
        pcall(function() local d = JSON.parse(resp.body); ok = d and d.ok; reason = d and d.reason end)
      end
      if ok then
        toast(okMsg or "تم ✓")
        S.clanScreen = "main"
        clanFetchMine()
      else
        toast(CLAN_REASONS[reason] or "تعذّرت العملية")
      end
      S.lastRanks = 0
    end)
  end)
end
function clanFetchMine()
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local url = base .. '/drive/clan/mine?name=' .. urlEncode(myName())
  pcall(function()
    web.get(url, function(err, resp)
      if not err and resp and resp.body then
        pcall(function()
          local d = JSON.parse(resp.body)
          if d and d.ok then
            S.myClan = d.clan or nil
            S.isOwner = (d.isOwner == true)
            S.isCoLeader = (d.isCoLeader == true)
            S.invites = d.invites or {}
            S.canCreate = (d.canCreate ~= false)
            S.myClanLoaded = true
          end
        end)
      end
    end)
  end)
end
local function clanFetchEmojis()
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local nm = myName()
  local url = base .. '/drive/clan/emojis'
  if nm ~= "" then url = url .. '?name=' .. urlEncode(nm) end
  pcall(function()
    web.get(url, function(err, resp)
      if not err and resp and resp.body then
        pcall(function()
          local d = JSON.parse(resp.body)
          if d and d.ok then
            local idxs = d.takenIdx or {}
            local taken = {}
            for _, i in ipairs(idxs) do if CLAN_EMOJIS_ALL[i + 1] then taken[#taken+1] = CLAN_EMOJIS_ALL[i + 1] end end
            S.clanEmojisTaken = taken
            if d.unlockedSlots then S.clanEmojiSlots = d.unlockedSlots end
            if d.perRow then S.clanEmojiPerRow = d.perRow end
          end
        end)
      end
    end)
  end)
end
local function clanFetchDetails(q)
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local url = base .. '/drive/clan/details?q=' .. urlEncode(q)
  pcall(function()
    web.get(url, function(err, resp)
      if not err and resp and resp.body then
        pcall(function()
          local d = JSON.parse(resp.body)
          if d and d.clan then
            S.clanView = d.clan; S.clanView.loading = false
          else
            S.clanView = { loading = false, name = q, owner = "؟", members = {}, count = 0, failed = true }
            toast("الكلان غير موجود")
          end
        end)
      end
    end)
  end)
end
local function openClanDetails(name)
  -- تُستدعى من داخل مودال البروفايل (زر "🛡️ الكلان") — لازم نقفل البروفايل
  -- وإلا يصير عندنا مودالين مفتوحين بنفس الوقت فوق بعض (نفس مشكلة التداخل).
  S.profileOpen = false
  S.clanView = { loading = true, name = name }
  S.clanOpen = true
  S.clanJustOpened = true
  clanFetchDetails(name)
end

--=================================================================
-- [9] شات الكلان + الخاص (REST — تسجيل دائم على البوت)
--=================================================================
local MSG_DIAG_LOGGED = {}
local function msgDiag(tag, err)
  if MSG_DIAG_LOGGED[tag] then return end
  MSG_DIAG_LOGGED[tag] = true
  ac.log('[DRIVE MESSAGES] ' .. tag .. ' فشل — تأكد من تركيب drive_messages_addon.js وريستارت البوت. الخطأ: ' .. tostring(err))
end
local function enrichMsgs(list)
  local out = {}
  for i, m in ipairs(list) do
    local r = S.ranks[m.name]
    out[i] = {
      id = m.id, name = m.name, text = m.text, sticker = m.sticker, t = m.t,
      avatar = (r and r.avatar) or nil, rank = (r and r.rank) or nil, rankColor = (r and r.color) or nil,
    }
  end
  return out
end
local function addClanMsg(m)
  if m.id and S.clanSeen[m.id] then return end
  if m.id then S.clanSeen[m.id] = true end
  S.clanLog[#S.clanLog + 1] = m
  while #S.clanLog > 200 do table.remove(S.clanLog, 1) end
  if (m.id or 0) > S.clanMaxId then S.clanMaxId = m.id end
  S.newClan = true
end
local function addDmMsg(withName, m)
  S.dmMsgs[withName] = S.dmMsgs[withName] or {}
  S.dmSeen[withName] = S.dmSeen[withName] or {}
  if m.id and S.dmSeen[withName][m.id] then return end
  if m.id then S.dmSeen[withName][m.id] = true end
  local arr = S.dmMsgs[withName]
  arr[#arr + 1] = m
  while #arr > 200 do table.remove(arr, 1) end
  if not S.dmLastId[withName] or (m.id or 0) > S.dmLastId[withName] then S.dmLastId[withName] = m.id end
  if S.activeDmWith == withName then S.newDm = true end
end
local function pollMessages()
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local nm = myName()
  if nm == "" then return end
  local clanSince = S.clanMaxId or 0
  local withName = S.activeDmWith
  local dmSince = 0
  if withName and withName ~= "" then dmSince = S.dmLastId[withName] or 0 end
  local url = base .. '/drive/messages/poll?name=' .. urlEncode(nm)
    .. '&clanSince=' .. tostring(clanSince) .. '&dmSince=' .. tostring(dmSince)
  if withName and withName ~= "" then url = url .. '&dmWith=' .. urlEncode(withName) end
  pcall(function()
    web.get(url, function(err, resp)
      if err or not resp then msgDiag('messages/poll', err); return end
      pcall(function()
        local d = JSON.parse(resp.body)
        if not (d and d.ok) then return end
        if d.clanMessages and #d.clanMessages > 0 then
          for _, m in ipairs(enrichMsgs(d.clanMessages)) do addClanMsg(m) end
        end
        S.dmConvs = d.dmList or {}
        if withName and withName ~= "" and d.dmMessages and #d.dmMessages > 0 then
          for _, m in ipairs(enrichMsgs(d.dmMessages)) do addDmMsg(withName, m) end
        end
      end)
    end)
  end)
end
local function clanSendChat(text, sticker)
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local body
  if sticker then body = '{"name":' .. jsonStr(myName()) .. ',"sticker":' .. jsonStr(sticker) .. '}'
  else body = '{"name":' .. jsonStr(myName()) .. ',"text":' .. jsonStr(text) .. '}' end
  pcall(function()
    web.post(base .. '/drive/clanchat/send', { ['Content-Type'] = 'application/json' }, body, function(err, resp)
      pollMessages()
    end)
  end)
end
local function dmSend(targetName, text, sticker)
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local body
  if sticker then body = '{"name":' .. jsonStr(myName()) .. ',"targetName":' .. jsonStr(targetName) .. ',"sticker":' .. jsonStr(sticker) .. '}'
  else body = '{"name":' .. jsonStr(myName()) .. ',"targetName":' .. jsonStr(targetName) .. ',"text":' .. jsonStr(text) .. '}' end
  pcall(function()
    web.post(base .. '/drive/dm/send', { ['Content-Type'] = 'application/json' }, body, function(err, resp)
      pollMessages()
    end)
  end)
end
local function dmRespond(withName, accept)
  if RANKS_URL == "" then return end
  local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
  local body = '{"name":' .. jsonStr(myName()) .. ',"withName":' .. jsonStr(withName) .. ',"accept":' .. (accept and 'true' or 'false') .. '}'
  pcall(function()
    web.post(base .. '/drive/dm/respond', { ['Content-Type'] = 'application/json' }, body, function(err, resp)
      toast(accept and "تم القبول ✅" or "تم الرفض")
      pollMessages()
    end)
  end)
end
local function openDm(withName)
  S.activeChannel = "dm"; S.activeDmWith = withName
  if not S.dmLoaded then S.dmLoaded = {} end
  local since = S.dmLoaded[withName] and (S.dmLastId[withName] or 0) or 0
  if not S.dmLoaded[withName] then S.dmLoaded[withName] = true; S.dmMsgs[withName] = {} end
  S.dmLastId[withName] = since
  S.wantFocusInput = true
  pollMessages()
end
local function closeDm() S.activeDmWith = nil end

--=================================================================
-- [10] اعتراض رسائل AC (الشات العام — استقبال)
--=================================================================
ac.onChatMessage(function(message, sender)
  local msg = tostring(message)
  if msg:find("not an administrator") or msg:find("Unrecognized command") then return true end
  if msg:find("^SYNTAX ERROR:") or msg:find("SYNTAX ERROR: Use '") then return true end
  if msg:find("^!TFC_") or msg:find("^!TRAFFIC") or msg:find("^!SHADDA") or msg:find("^!RADAR") then return true end
  if msg:find("Slot %[") or msg:find("is not configured") then return true end
  if sender == 0 then return true end -- صدى رسالتي أنا — عرضناها محلياً فور الإرسال
  local sidx = msg:match("^%$STICK:(%d+)$")
  if sidx then
    local url = ALLPICS[tonumber(sidx)]
    if url then
      local ssrv = not sender or sender < 0
      local snm = ssrv and "السيرفر" or (ac.getDriverName(sender) or ("لاعب " .. tostring(sender)))
      local rr = S.ranks[snm]
      pushLog({ name = snm, sticker = url, srv = ssrv, mine = false, t = S.clock, avatar = (rr and rr.avatar) or nil })
    end
    return true
  end
  local srv = not sender or sender < 0
  local nm = srv and "السيرفر" or (ac.getDriverName(sender) or ("لاعب " .. tostring(sender)))
  if srv then
    local carN, drv = msg:match("^Car (%d+) is now driven by (.+)$")
    if carN then msg = "السيارة " .. carN .. " صار يقودها " .. drv
    elseif msg:find("shutting down", 1, true) then msg = "⚠️ السيرفر يسوي ريستارت — نرجع خلال ثواني، أعد الدخول 🔄"
    elseif msg:find("You have been kicked", 1, true) then msg = "تم طردك من السيرفر"
    elseif msg:find("You have been banned", 1, true) then msg = "تم حظرك من السيرفر"
    end
  end
  local rr = S.ranks[nm]
  pushLog({ name = nm, text = msg, srv = srv, mine = false, t = S.clock, avatar = (rr and rr.avatar) or nil })
  return true
end)

pushLog({ name = "DRIVE", text = "مرحباً بك في سيرفر DRIVE! · اضغط C لإظهار/إخفاء الشات 🧡", srv = true, t = 0 })
for _, rx in ipairs({ "onnected", "joined the server", "left the server", "has left" }) do
  pcall(function() ac.blockSystemMessages(rx) end)
end

--=================================================================
-- [11] إخفاء شات CSP الأصلي (نفس طريقة IDDL)
--=================================================================
pcall(function()
  pcall(ui.onChat, function(mode, readOnlyMode)
    local t = rgbm(0, 0, 0, 0)
    ui.pushStyleColor(ui.StyleColor.WindowBg, t)
    ui.pushStyleColor(ui.StyleColor.TitleBg, t)
    ui.pushStyleColor(ui.StyleColor.TitleBgActive, t)
    ui.pushStyleColor(ui.StyleColor.TitleBgCollapsed, t)
    ui.pushStyleColor(ui.StyleColor.Border, t)
    ui.pushStyleColor(ui.StyleColor.BorderShadow, t)
    ui.pushStyleColor(ui.StyleColor.ChildBg, t)
    ui.pushStyleColor(ui.StyleColor.PopupBg, t)
    ui.pushStyleColor(ui.StyleColor.Text, t)
    ui.pushStyleColor(ui.StyleColor.Button, t)
    ui.pushStyleColor(ui.StyleColor.ButtonHovered, t)
    ui.pushStyleColor(ui.StyleColor.ButtonActive, t)
    ui.pushStyleVarAlpha(0)
    ui.popStyleColor(12)
    ui.popStyleVar()
    return true
  end, function() return true end)
end)

--=================================================================
-- [12] أدوات الرسم المشتركة (أفاتار / فقاعات / أزرار)
--=================================================================
local function dwBox2(t, s, x, y, w, h, c)
  ui.pushDWriteFont(FONT); ui.setCursor(vec2(x, y))
  ui.dwriteTextAligned(t, s, ui.Alignment.Center, ui.Alignment.Center, vec2(w, h), false, c or CW)
  ui.popDWriteFont()
end
local function dwLeft2(t, s, x, y, w, h, c)
  ui.pushDWriteFont(FONT); ui.setCursor(vec2(x, y))
  ui.dwriteTextAligned(t, s, ui.Alignment.Start, ui.Alignment.Center, vec2(w, h), false, c or CW)
  ui.popDWriteFont()
end
local AV_COLS = {
  rgbm(0.86, 0.30, 0.24, 1), rgbm(0.24, 0.52, 0.88, 1), rgbm(0.53, 0.34, 0.83, 1),
  rgbm(0.18, 0.62, 0.55, 1), rgbm(0.88, 0.53, 0.14, 1), rgbm(0.34, 0.58, 0.30, 1),
  rgbm(0.80, 0.34, 0.55, 1), rgbm(0.33, 0.44, 0.74, 1), rgbm(0.62, 0.45, 0.20, 1),
}
local function nameHash(s)
  s = s or "?"; local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 100000 end
  return h
end
local function firstUtf8(s)
  if not s or s == "" then return "?" end
  local b = s:byte(1); local n = 1
  if b >= 240 then n = 4 elseif b >= 224 then n = 3 elseif b >= 192 then n = 2 end
  return s:sub(1, n)
end
local function initials(name)
  name = name or "?"
  if name:match("^[A-Za-z]") then return name:sub(1, 2):upper() end
  return firstUtf8(name)
end
local function hexToColor(hex, a)
  hex = (hex or ""):gsub("#", "")
  if #hex ~= 6 then return rgbm(0.53, 0.34, 0.83, a or 1) end
  local r = tonumber(hex:sub(1,2), 16) or 135
  local g = tonumber(hex:sub(3,4), 16) or 87
  local b = tonumber(hex:sub(5,6), 16) or 212
  return rgbm(r / 255, g / 255, b / 255, a or 1)
end
local function hslToHex(h, s, l)
  s = s / 100; l = l / 100
  local function k(n) return (n + h / 30) % 12 end
  local a = s * math.min(l, 1 - l)
  local function f(n)
    local kk = k(n)
    return l - a * math.max(-1, math.min(kk - 3, math.min(9 - kk, 1)))
  end
  local function toHex(x) return string.format("%02X", math.floor(math.max(0, math.min(1, x)) * 255 + 0.5)) end
  return "#" .. toHex(f(0)) .. toHex(f(8)) .. toHex(f(4))
end
local function drawAvatar(cx, cy, r, m)
  if m.srv then
    ui.drawCircleFilled(vec2(cx, cy), r, rgbm(0.05, 0.05, 0.06, 1))
    ui.drawCircle(vec2(cx, cy), r, rgbm(ACC.r, ACC.g, ACC.b, 0.95), 30, 2)
    dwBox2("D", r * 1.05, cx - r, cy - r, r * 2, r * 2, ACC)
    return
  end
  local av = m.avatar
  if (not av or av == "" or av == false) and m.name then
    local rr = S.ranks[m.name]
    if rr and rr.avatar and rr.avatar ~= "" then av = rr.avatar; m.avatar = av end
  end
  if av and av ~= "" and av ~= false then
    if ui.isImageReady(av) then
      local ok = pcall(function()
        if ui.drawImageRounded then
          ui.drawImageRounded(av, vec2(cx - r, cy - r), vec2(cx + r, cy + r), r)
        else
          ui.drawImage(av, vec2(cx - r, cy - r), vec2(cx + r, cy + r))
        end
      end)
      if ok then ui.drawCircle(vec2(cx, cy), r, rgbm(ACC.r, ACC.g, ACC.b, 0.6), 30, 1.5); return end
    else
      pcall(function() ui.decodeImage(av) end)
    end
  end
  local col = AV_COLS[1 + (nameHash(m.name or "?") % #AV_COLS)]
  ui.drawCircleFilled(vec2(cx, cy), r, col)
  ui.drawCircle(vec2(cx, cy), r, rgbm(1, 1, 1, 0.18), 30, 1.5)
  dwBox2(initials(m.name), r * 0.92, cx - r, cy - r, r * 2, r * 2, CW)
end
local function drawBadge(x, y, rank, rankColor)
  if not rank or rank == "" then return 0 end
  local label = tostring(rank):upper()
  local w = math.ceil(ui.measureDWriteText(label, 10.5, 400).x) + 12
  local col = rankColor and hexToColor(rankColor, 0.9) or ACC
  local kl = tostring(rank):lower()
  if RANK_LABEL[kl] then label = RANK_LABEL[kl] end
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + 16), col, 5)
  ui.setCursor(vec2(x, y - 1))
  ui.dwriteTextAligned(label, 10.5, ui.Alignment.Center, ui.Alignment.Center, vec2(w, 18), false, CW)
  return w
end
-- زر بسيط (نص/أيقونة داخل مربع) — يرجع true لو انضغط
local function iconButton(id, x, y, w, h, label, active, size)
  ui.setCursor(vec2(x, y))
  local clicked = ui.invisibleButton(id, vec2(w, h))
  local hover = ui.itemHovered()
  local bg = active and rgbm(ACC.r, ACC.g, ACC.b, 0.95) or (hover and rgbm(1, 1, 1, 0.10) or rgbm(1, 1, 1, 0.045))
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), bg, 8)
  dwBox2(label, size or 15, x, y, w, h, active and rgbm(0.08,0.05,0.02,1) or CW)
  if hover then ui.setMouseCursor(ui.MouseCursor.Hand) end
  return clicked
end
local function textButton(id, x, y, w, h, label, primary)
  ui.setCursor(vec2(x, y))
  local clicked = ui.invisibleButton(id, vec2(w, h))
  local hover = ui.itemHovered()
  local bg = primary and (hover and rgbm(1.0, 0.60, 0.16, 1) or ACC) or (hover and rgbm(0.14, 0.135, 0.19, 1) or rgbm(0.10, 0.10, 0.125, 1))
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), bg, 9)
  dwBox2(label, 13, x, y, w, h, primary and rgbm(0.08,0.05,0.02,1) or CW)
  if hover then ui.setMouseCursor(ui.MouseCursor.Hand) end
  return clicked
end

-- صندوق كتابة يعرض العربي صحيح (متّصل الحروف وباتجاه صحيح) أثناء الكتابة
-- نفسها، مو بس بعد الإرسال. سبب المشكلة: عارض النص الافتراضي لـ ui.inputText
-- ما يسوي "shaping" للعربي، فيطلع الحروف منفصلة ومعكوسة الترتيب وأنت تكتب.
-- الحل (نفس طريقة صندوق تنبيه الرادار بمنيو الإدمن، اللي أرسله المستخدم كمرجع):
-- نرسم ui.inputText حقيقي (يتولى الفوكس/المؤشر/النسخ فعلياً — بس نخفي شكله)،
-- نغطيه بمستطيل، ثم نرسم القيمة نفسها يدوياً فوقه بـ ui.dwriteTextAligned
-- (محاذاة End = يمين، مع Shaping صحيح) — نفس الأسلوب المستخدم أصلاً لعرض كل
-- رسائل الشات المُرسلة (drawMsgRow). القيمة المخزّنة بالمتغير نفسها سليمة
-- دايماً بكل الأحوال (المشكلة كانت بالعرض بس، مو بالنص المُرسَل فعلياً).
-- ui.inputText (مثل أي ودجت Dear ImGui) ما يعيد نسخ قيمة "value" اللي نمرّرها
-- لداخل بافره الداخلي طالما نفس الـ id لسا نشط/بالفوكس — هذا سلوك موثّق
-- بمرجع الرادار (radarInputGen) وسببه تصفير صندوق الشات ما يشتغل بعد الإرسال
-- (يفضل يعرض آخر قيمة كتبناها إحنا يدوياً، مو الفاضية الجديدة). الحل: نتابع
-- آخر قيمة رجّعناها لكل id، ولو "value" الجايه من بره اختلفت عنها (يعني فيه
-- تغيير برمجي خارجي — تصفير بعد إرسال، إضافة إيموجي/منشن، الخ) نغيّر معرّف
-- الودجت نفسه فيجبر CSP يبنيه من جديد ويطلع بالقيمة الصحيحة فوراً.
local ARIN_STATE = {}
local function arInputText(id, x, y, w, h, value, placeholder, grow, maxH)
  value = value or ""
  local st = ARIN_STATE[id]
  if not st then st = { lastOut = value, gen = 0 }; ARIN_STATE[id] = st end
  if value ~= st.lastOut then
    st.gen = st.gen + 1
    st.lastOut = value
  end
  local realId = id .. "_g" .. st.gen

  local sz = 15
  local boxH = h
  if grow then
    local measureText = value ~= "" and value or " "
    ui.pushDWriteFont(FONT)
    local msz = ui.measureDWriteText(measureText, sz, w - 20)
    ui.popDWriteFont()
    boxH = math.max(h, math.min(maxH or (h * 4), math.ceil(msz.y) + 18))
  end

  -- نستدعي ui.inputText بشكل بسيط (سطر واحد، بدون تمرير حجم vec2) — بالضبط
  -- زي مرجع صندوق الرادار (ما يستخدم حجم مخصص حتى لصندوقه المتنامي)؛ الحجم/
  -- الالتفاف المرئي كله نتحكم فيه إحنا يدوياً بالرسم اللي تحت، مو بالودجت نفسه.
  -- كمان نخفي رسم الودجت الداخلي بالكامل (نص + خلفية + حدّ) بنفس طريقة إخفاء
  -- شات CSP الأصلي المثبتة بـ player_menu.lua (StyleColor شفاف) — عشان ما
  -- يصير أي "تسريب" لحظي لرسمه الداخلي (بخط ImGui الافتراضي، مو خطنا العريض)
  -- فوق رسمتنا اليدوية أثناء الكتابة الفعلية، وهذا سبب إحساس "الخط ما يجي
  -- بوزنه الصح" وقت الضغط للكتابة رغم إن الصندوق نفسه كبير وصحيح.
  -- نمرر حجم صريح (w, boxH) لـ ui.inputText بدل ما نسيبه ياخذ ارتفاعه
  -- الافتراضي (سطر واحد بخط ImGui الافتراضي) — لو تركناه بدون حجم، ودجته
  -- الحقيقية تطلع أصغر بكثير من صندوقنا الكبير (خصوصاً صناديق الوصف/الإدمن
  -- اللي تكبر)، فيبين خط/حدّ رفيع من رسمه الداخلي في نص الصندوق (فوق رسمتنا،
  -- بغض النظر عن ترتيب الرسم — بالضبط زي مشكلة ChildBg). تمرير نفس حجم
  -- صندوقنا بالضبط يخلي ودجته الحقيقية تملأ نفس المساحة اللي نغطيها بالضبط،
  -- فيختفي أي خط متسرّب. هذا نفس أسلوب النسخة الأقدم من هالملف (قبل إصلاح
  -- تشكيل العربي) اللي كانت تمرر حجم صريح لنفس الصناديق.
  ui.setCursor(vec2(x, y))
  ui.setNextItemWidth(w)
  local trans = rgbm(0, 0, 0, 0)
  ui.pushStyleColor(ui.StyleColor.Text, trans)
  ui.pushStyleColor(ui.StyleColor.FrameBg, trans)
  ui.pushStyleColor(ui.StyleColor.FrameBgHovered, trans)
  ui.pushStyleColor(ui.StyleColor.FrameBgActive, trans)
  ui.pushStyleColor(ui.StyleColor.Border, trans)
  local nv, changed, entered = ui.inputText(realId, value, ui.InputTextFlags.RetainSelection, vec2(w, boxH))
  ui.popStyleColor(5)
  local focused = ui.itemActive() or ui.itemFocused()
  if focused then
    pcall(function() ac.setCurrentInputMethod(ac.UserInputMode.UI); ui.captureKeyboard(true) end)
    S.chatTyping = true
  end
  local outVal = changed and nv or value
  if changed then st.lastOut = outVal end

  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + boxH), rgbm(0.11, 0.115, 0.14, 1), 8)
  ui.drawRect(vec2(x, y), vec2(x + w, y + boxH), rgbm(ACC.r, ACC.g, ACC.b, 0.30), 8, nil, 1)
  ui.pushDWriteFont(FONT)
  if outVal ~= "" then
    ui.setCursor(vec2(x + 10, grow and (y + 5) or y))
    ui.dwriteTextAligned(outVal, sz, ui.Alignment.End, grow and ui.Alignment.Start or ui.Alignment.Center, vec2(w - 20, boxH - 8), grow and true or false, CW)
  elseif placeholder and placeholder ~= "" then
    ui.setCursor(vec2(x + 10, y))
    ui.dwriteTextAligned(placeholder, sz, ui.Alignment.End, ui.Alignment.Center, vec2(w - 20, boxH), false, CDm)
  end
  ui.popDWriteFont()
  return outVal, changed, entered, boxH
end

-- ui.childWindow يرسم خلفيته الخاصة (ChildBg) فوق أي مستطيل نرسمه إحنا يدوياً
-- قبله (سجل الرسائل + قائمة الأعضاء + قائمة القنوات كلها childWindow). نلغي
-- خلفية ChildBg بالكامل (شفافة 0,0,0,0) عشان خلفيتنا المرسومة يدوياً هي
-- الوحيدة الظاهرة دايماً — يبقى مفيد حتى بعد شيل خيار الشفافية (BGA ثابتة
-- الحين)، لأنه يمنع أي تعارض ألوان بين خلفية CSP الافتراضية وخلفيتنا.
local function childWindowT(id, size, fn)
  ui.pushStyleColor(ui.StyleColor.ChildBg, rgbm(0, 0, 0, 0))
  ui.childWindow(id, size, fn)
  ui.popStyleColor(1)
end

--=================================================================
-- [13] فقاعات الإشعارات (Native — لما الشات مقفول) — كما هي بلا تغيير
--=================================================================
local function bubbleInner(m, areaW)
  if m.sticker then return 96, 96 end
  local maxInner = math.floor((areaW - 20 * 2 - 44) * 0.94)
  local nat = ui.measureDWriteText(m.text or "", 15, 4000)
  local innerW = math.max(30, math.min(maxInner, math.ceil(nat.x) + 2))
  local wr = ui.measureDWriteText(m.text or "", 15, innerW)
  return innerW, math.max(18, math.ceil(wr.y))
end
local function msgRowH(m, areaW)
  local _, contentH = bubbleInner(m, areaW)
  return 24 + (contentH + 16) + 14
end
local AVR = 20
local function drawMsgRow(m, x, areaW, yy, a)
  a = a or 1
  local mine = m.mine and not m.srv
  local dispName = m.srv and "DRIVE SYSTEM" or (m.name or "?")
  local nameCol = rgbm(ACC.r, ACC.g, ACC.b, a)
  local innerW, contentH = bubbleInner(m, areaW)
  local bubW, bubH = innerW + 24, contentH + 16
  local avcy, bubY = yy + AVR + 2, yy + 24
  local bx1, bx2
  if mine then
    drawAvatar(x + areaW - AVR - 2, avcy, AVR, m)
    local rightEdge = x + areaW - AVR * 2 - 12
    local nmW = math.min(220, math.ceil(ui.measureDWriteText(dispName, 14, 400).x) + 4)
    ui.pushDWriteFont(FONT); ui.setCursor(vec2(rightEdge - nmW, yy))
    ui.dwriteTextAligned(dispName, 14, ui.Alignment.End, ui.Alignment.Center, vec2(nmW, 18), false, nameCol)
    ui.popDWriteFont()
    bx2 = rightEdge; bx1 = bx2 - bubW
    ui.drawRectFilled(vec2(bx1, bubY), vec2(bx2, bubY + bubH), rgbm(0.15, 0.15, 0.17, 0.96 * a), 12)
    ui.drawRect(vec2(bx1, bubY), vec2(bx2, bubY + bubH), rgbm(ACC.r, ACC.g, ACC.b, 0.3 * a), 12, nil, 1)
    ui.drawRectFilled(vec2(bx2 - 3, bubY + 4), vec2(bx2, bubY + bubH - 4), rgbm(ACC.r, ACC.g, ACC.b, 0.95 * a), 2)
  else
    drawAvatar(x + AVR + 2, avcy, AVR, m)
    local nameX = x + AVR * 2 + 12
    dwLeft2(dispName, 14, nameX, yy, 240, 18, nameCol)
    if not m.srv and isLinked(m.name) then
      local nmW = math.min(240, math.ceil(ui.measureDWriteText(dispName, 14, 400).x) + 4)
      local bx = nameX + nmW + 5
      ui.drawRectFilled(vec2(bx, yy + 2), vec2(bx + 15, yy + 16), rgbm(0.13, 0.6, 0.4, 0.9 * a), 4)
      ui.setCursor(vec2(bx, yy + 1)); ui.dwriteTextAligned("✓", 11, ui.Alignment.Center, ui.Alignment.Center, vec2(15, 15), false, rgbm(1, 1, 1, a))
    end
    bx1 = nameX; bx2 = bx1 + bubW
    ui.drawRectFilled(vec2(bx1, bubY), vec2(bx2, bubY + bubH), m.srv and rgbm(0.11, 0.115, 0.14, 0.96 * a) or rgbm(0.17, 0.17, 0.19, 0.96 * a), 12)
    ui.drawRect(vec2(bx1, bubY), vec2(bx2, bubY + bubH), m.srv and rgbm(ACC.r, ACC.g, ACC.b, 0.35 * a) or rgbm(1, 1, 1, 0.07 * a), 12, nil, 1)
    if m.srv then ui.drawRectFilled(vec2(bx1, bubY + 4), vec2(bx1 + 3, bubY + bubH - 4), rgbm(ACC.r, ACC.g, ACC.b, 0.9 * a), 2) end
  end
  if m.sticker then
    if ui.isImageReady(m.sticker) then
      pcall(function() ui.drawImage(m.sticker, vec2(bx1 + 12, bubY + 8), vec2(bx1 + 108, bubY + 104)) end)
    else
      pcall(function() ui.decodeImage(m.sticker) end)
      ui.drawRectFilled(vec2(bx1 + 12, bubY + 8), vec2(bx1 + 108, bubY + 104), rgbm(0.16, 0.16, 0.19, 1), 8)
    end
  else
    ui.setCursor(vec2(bx1 + 12, bubY + 8))
    ui.dwriteTextAligned(m.text or "", 15, ui.Alignment.End, ui.Alignment.Start, vec2(innerW, contentH), true,
      m.srv and rgbm(CY.r, CY.g, CY.b, a) or rgbm(1, 1, 1, a))
  end
  return 24 + bubH + 14
end
local function drawChatLog(sim)
  if #S.log == 0 then return end
  if not cStor.dc_notif then return end
  if S.open then return end
  local recent = {}
  for i = #S.log, math.max(1, #S.log - 12), -1 do
    local lm = S.log[i]
    if not lm.mine and (S.clock - lm.t < 16) then table.insert(recent, 1, lm) end
    if #recent >= 6 then break end
  end
  if #recent == 0 then return end
  local w = 620
  local hs, total = {}, 6
  for i, m in ipairs(recent) do hs[i] = msgRowH(m, w); total = total + hs[i] end
  local cy0 = sim.windowHeight - total - 190
  local lx = math.max(0, math.min(sim.windowWidth - w, cStor.dc_logX or 16))
  local ly = ((cStor.dc_logY or -1) >= 0) and cStor.dc_logY or cy0
  ly = math.max(0, math.min(sim.windowHeight - total, ly))
  ui.transparentWindow("driveChatLog", vec2(lx, ly), vec2(w, total), function()
    local lp = ui.mouseLocalPos()
    local over = lp.x >= -6 and lp.x <= (w + 6) and lp.y >= -6 and lp.y <= (total + 6)
    if over and ui.mouseDown(ui.MouseButton.Left) and not ui.anyItemActive() and not S.logDrag then
      S.logDrag = true; S.logDragStart = ui.mousePos(); S.logOfsStart = vec2(lx, ly)
    end
    if S.logDrag then
      if ui.mouseDown(ui.MouseButton.Left) then
        local mp = ui.mousePos()
        cStor.dc_logX = S.logOfsStart.x + (mp.x - S.logDragStart.x)
        cStor.dc_logY = S.logOfsStart.y + (mp.y - S.logDragStart.y)
      else S.logDrag = false end
    end
    local target = (over or S.logDrag or (S.clock - S.log[#S.log].t < 4)) and 1 or 0
    S.chatReveal = (S.chatReveal or 1) + (target - (S.chatReveal or 1)) * 0.14
    local rv = S.chatReveal
    local yy = 2
    for i, m in ipairs(recent) do
      local age = S.clock - m.t
      local a = (age > 13 and math.max(0, 1 - (age - 13) / 3) or 1) * rv
      drawMsgRow(m, 0, w, yy, a)
      yy = yy + hs[i]
    end
  end)
end

--=================================================================
-- [14] فتح/قفل الشات
--=================================================================
local function openChat()
  S.open = true
  S.wantFocusInput = true
end
local function closeChat()
  S.open = false; S.wantsKbd = false; S.dragging = false
  S.profileOpen = false; S.adminOpen = false; S.newConvOpen = false; S.clanOpen = false
end

--=================================================================
-- [15] رسم منطقة سجل رسائل (عام/كلان/خاص) — قابلة للتمرير + سكرول تلقائي للأسفل
--=================================================================
local function drawLogBubble(m, mine, w)
  -- فقاعة داخل نافذة الشات الرئيسية (أوسع من فقاعات الإشعارات، بدون تلاشي)
  return drawMsgRow(m, 0, w, 0, 1)
end
local function renderMsgList(id, x, y, w, h, list, myPredicate, onOpenProfile, forceScrollBottom)
  ui.setCursor(vec2(x, y))
  childWindowT(id, vec2(w, h), function()
    local innerW = w - 16
    local yy = 6
    for _, m in ipairs(list) do
      local mine = myPredicate(m)
      local rh = msgRowH(m, innerW)
      ui.setCursor(vec2(0, yy))
      -- منطقة نقر فوق الاسم لفتح البروفايل (تقريبية: كامل عرض الصف قرب الاسم)
      if onOpenProfile and not mine and not m.srv then
        local hit = ui.invisibleButton(id .. "##hit" .. tostring(yy), vec2(innerW, 20))
        if hit then onOpenProfile(m.name) end
        ui.setCursor(vec2(0, yy))
      end
      drawMsgRow(m, 0, innerW, yy, 1)
      yy = yy + rh
    end
    if forceScrollBottom then ui.setScrollY(1e9) end
  end)
end

--=================================================================
-- [16] رسم قائمة الأعضاء (السايدبار اليسرى)
--=================================================================
local function rankOrderOf(r)
  local k = tostring(r or ""):lower()
  if k == "admin" then return 0 elseif k == "mod" then return 1 elseif k == "vip" then return 2
  elseif r and r ~= "" then return 3 else return 4 end
end
local function drawMemberSidebar(x, y, w, h)
  local bga = S.bgAlpha or 1
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), rgbm(0.067, 0.063, 0.082, bga), 12)
  ui.drawRect(vec2(x, y), vec2(x + w, y + h), rgbm(1, 1, 1, 0.06 * bga), 12, nil, 1)
  dwLeft2("👥 الأعضاء (" .. #S.members .. ")", 15, x + 14, y + 10, w - 28, 22, CW)
  -- بحث
  local newSearch = arInputText("##memsearch", x + 12, y + 36, w - 24, 26, S.memberSearch, "ابحث عن عضو...")
  S.memberSearch = newSearch
  -- ترتيب: أنا أولاً، ثم الرتبة، ثم الاسم
  local sorted = {}
  for _, m in ipairs(S.members) do sorted[#sorted + 1] = m end
  table.sort(sorted, function(a, b)
    if a.isMe ~= b.isMe then return a.isMe end
    local ra, rb = rankOrderOf(a.rank), rankOrderOf(b.rank)
    if ra ~= rb then return ra < rb end
    return (a.name or "") < (b.name or "")
  end)
  local q = (S.memberSearch or ""):lower()
  ui.setCursor(vec2(x + 6, y + 64))
  childWindowT("##mlistc", vec2(w - 12, h - 74), function()
    local yy = 4
    for _, m in ipairs(sorted) do
      if q == "" or (m.name or ""):lower():find(q, 1, true) then
        ui.setCursor(vec2(4, yy))
        local clicked = ui.invisibleButton("##mrow" .. m.name, vec2(w - 24, 46))
        local hover = ui.itemHovered()
        if hover then
          ui.drawRectFilled(vec2(4, yy), vec2(w - 20, yy + 46), rgbm(ACC.r, ACC.g, ACC.b, 0.10), 8)
          ui.setMouseCursor(ui.MouseCursor.Hand)
        end
        drawAvatar(4 + 22, yy + 23, 20, { name = m.name, avatar = m.avatar, srv = false })
        local subtitle = m.isMe and "أنت" or (m.speed and ("💨 " .. tostring(m.speed) .. " كم/س") or "متصل")
        local nameX = 4 + 48
        dwLeft2(m.name or "?", 14, nameX, yy + 3, w - 120, 18, ACC)
        -- الشارة لازم تُرسم بعد نهاية اسم اللاعب فعلياً (نقيس عرض النص أولاً)
        -- وإلا تتراكب فوق الاسم — نفس نمط علامة التوثيق (✓) في drawMsgRow.
        local nameW = math.min(w - 170, math.ceil(ui.measureDWriteText(m.name or "?", 14, 400).x) + 6)
        local bw = drawBadge(nameX + nameW, yy + 3, m.rank, m.rankColor)
        dwLeft2(subtitle, 11.5, nameX, yy + 23, w - 120, 16, CDm)
        if m.discord then dwLeft2("🔗", 12, w - 44, yy + 12, 20, 18, rgbm(0.4,0.7,1,1)) end
        if clicked then S.profileOpen = true; S.profileName = m.name; S.descLoadedFor = nil; S.profileJustOpened = true end
        yy = yy + 50
      end
    end
  end)
end

--=================================================================
-- [17] القناة الجانبية (عام/كلان/خاص)
--=================================================================
local function switchChannel(ch)
  if ch ~= "dm" and S.activeDmWith then S.activeDmWith = nil end
  S.activeChannel = ch
  if ch == "clan" then
    if not S.myClanLoaded then
      clanFetchMine()
      local tk = (S.clanLoadToken or 0) + 1; S.clanLoadToken = tk
    else
      pollMessages()
    end
  elseif ch == "dm" then
    if not S.activeDmWith then pollMessages() end
  end
  S.wantFocusInput = true
end
local function drawChannelSidebar(x, y, w, h)
  local bga = S.bgAlpha or 1
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), rgbm(0.067, 0.063, 0.082, bga), 12)
  ui.drawRect(vec2(x, y), vec2(x + w, y + h), rgbm(1, 1, 1, 0.06 * bga), 12, nil, 1)
  local tw = (w - 24) / 3
  if iconButton("##chtabg", x + 8, y + 10, tw, 40, "🌐 عامة", S.activeChannel == "general") then switchChannel("general") end
  if iconButton("##chtabc", x + 12 + tw, y + 10, tw, 40, "🛡️ الكلان", S.activeChannel == "clan") then switchChannel("clan") end
  if iconButton("##chtabd", x + 16 + tw * 2, y + 10, tw, 40, "👤 خاصة", S.activeChannel == "dm") then switchChannel("dm") end

  local listY = y + 58
  local listH = h - 66
  if S.activeChannel == "dm" then
    -- بحث + زر محادثة جديدة
    local ns = arInputText("##dmsearch", x + 10, listY, w - 20, 26, S.dmSearch, "ابحث في المحادثات...")
    S.dmSearch = ns
    listY = listY + 30; listH = listH - 30 - 40
  end
  ui.setCursor(vec2(x + 8, listY))
  childWindowT("##chlistc", vec2(w - 16, listH), function()
    if S.activeChannel == "general" then
      ui.drawRectFilled(vec2(4, 4), vec2(w - 24, 60), rgbm(ACC.r, ACC.g, ACC.b, 0.14), 10)
      dwLeft2("دردشة عامة", 14, 46, 12, w - 60, 20, CW)
      dwLeft2("دردشة عامة لجميع اللاعبين", 11, 46, 32, w - 60, 16, CDm)
      dwBox2("🌐", 18, 8, 10, 32, 32)
    elseif S.activeChannel == "clan" then
      if not S.myClanLoaded then
        dwLeft2("⏳ جاري التحقق من كلانك...", 12.5, 8, 10, w - 24, 30, CDm)
      elseif not S.myClan then
        dwLeft2("🛡️ انضم لكلان أول عشان تشوف شاته", 12.5, 8, 10, w - 24, 40, CDm)
      else
        ui.drawRectFilled(vec2(4, 4), vec2(w - 24, 60), rgbm(ACC.r, ACC.g, ACC.b, 0.14), 10)
        dwLeft2("دردشة " .. (S.myClan.name or ""), 13.5, 46, 12, w - 60, 20, CW)
        dwLeft2("خاصة بأعضاء الكلان", 11, 46, 32, w - 60, 16, CDm)
        dwBox2(S.myClan.emoji or "🛡️", 18, 8, 10, 32, 32)
      end
    elseif S.activeChannel == "dm" then
      if S.activeDmWith then
        ui.setCursor(vec2(4, 4))
        local clicked = ui.invisibleButton("##dmback", vec2(w - 24, 46))
        ui.drawRectFilled(vec2(4, 4), vec2(w - 24, 50), rgbm(ACC.r, ACC.g, ACC.b, 0.14), 10)
        dwLeft2("◀ " .. S.activeDmWith, 13.5, 12, 8, w - 40, 20, CW)
        dwLeft2("اضغط للرجوع لقائمة المحادثات", 11, 12, 26, w - 40, 16, CDm)
        if clicked then closeDm() end
      else
        local q = (S.dmSearch or ""):lower()
        local reqs, others = {}, {}
        for _, c in ipairs(S.dmConvs) do
          if q == "" or (c.withName or ""):lower():find(q, 1, true) then
            if c.status == "pending" and not c.isInitiator then reqs[#reqs+1] = c else others[#others+1] = c end
          end
        end
        if #S.dmConvs == 0 then
          dwLeft2("💬 ما عندك محادثات خاصة بعد", 12.5, 8, 6, w - 24, 40, CDm)
        end
        local yy = 4
        if #reqs > 0 then
          dwLeft2("✉️ طلبات محادثة (" .. #reqs .. ")", 11.5, 8, yy, w - 24, 18, CDm); yy = yy + 20
          for _, c in ipairs(reqs) do
            ui.drawRectFilled(vec2(4, yy), vec2(w - 24, yy + 44), rgbm(0.09, 0.088, 0.118, 1), 9)
            dwLeft2(c.withName or "؟", 13, 12, yy + 4, w - 100, 18, CW)
            dwLeft2(c.lastText or "", 10.5, 12, yy + 22, w - 100, 15, CDm)
            if textButton("##dmacc" .. c.withName, w - 76, yy + 8, 28, 28, "✓", true) then dmRespond(c.withName, true) end
            if textButton("##dmrej" .. c.withName, w - 42, yy + 8, 28, 28, "✕", false) then dmRespond(c.withName, false) end
            yy = yy + 48
          end
        end
        if #others > 0 then
          for _, c in ipairs(others) do
            ui.setCursor(vec2(4, yy))
            local clicked = ui.invisibleButton("##dmrow" .. c.withName, vec2(w - 24, 46))
            local hover = ui.itemHovered()
            if hover then ui.drawRectFilled(vec2(4, yy), vec2(w - 24, yy + 44), rgbm(1,1,1,0.05), 9); ui.setMouseCursor(ui.MouseCursor.Hand) end
            local sub = (c.status == 'pending' and c.isInitiator) and "⏳ بانتظار الموافقة" or (c.lastText or "")
            dwLeft2(c.withName or "؟", 13, 12, yy + 3, w - 90, 18, CW)
            dwLeft2(sub, 10.5, 12, yy + 22, w - 90, 15, CDm)
            if c.unread and c.unread > 0 then
              ui.drawRectFilled(vec2(w - 56, yy + 14), vec2(w - 30, yy + 34), ACC, 20)
              dwBox2(tostring(c.unread), 11, w - 56, yy + 14, 26, 20, rgbm(0.08,0.05,0.02,1))
            end
            if clicked then openDm(c.withName) end
            yy = yy + 50
          end
        end
      end
    end
  end)
  if S.activeChannel == "dm" and not S.activeDmWith then
    if textButton("##newconv", x + 10, y + h - 38, w - 20, 30, "+ محادثة جديدة", false) then
      S.newConvOpen = true; S.newConvSearch = ""; S.newConvJustOpened = true
    end
  end
end

--=================================================================
-- [18] منتقي الملصقات/الإيموجي/الGIF/الجمل
--=================================================================
local function sendStickerActive(url)
  if S.activeChannel == "clan" then
    if not S.myClan then toast("انضم لكلان أول"); return end
    -- بدون إضافة محلية بمعرّف وهمي — نفس سبب منع التكرار بالرسائل النصية.
    clanSendChat(nil, url)
  elseif S.activeChannel == "dm" then
    if not S.activeDmWith then toast("افتح محادثة أول"); return end
    dmSend(S.activeDmWith, nil, url)
  else
    ownMsg(nil, url)
    local idx = PICIDX[url]
    if idx then pcall(function() ac.sendChatMessage('$STICK:' .. idx) end) end
    relayChatLog('[ملصق]')
  end
  S.activePicker = nil
end
local PICKER_TITLES = { emoji = "الإيموجي", stick = "الملصقات", phr = "جمل جاهزة" }
local function drawPickerPanel(x, y, w)
  if not S.activePicker then return 0 end
  local ph = 170
  local py = y - ph - 6
  ui.drawRectFilled(vec2(x, py), vec2(x + w, py + ph), rgbm(0.06, 0.058, 0.075, 0.98), 12)
  ui.drawRect(vec2(x, py), vec2(x + w, py + ph), rgbm(ACC.r, ACC.g, ACC.b, 0.4), 12, nil, 1)
  -- شريط علوي ثابت (خارج منطقة التمرير) فيه عنوان + زر إغلاق صريح — قبل كذا
  -- ما كان فيه أي طريقة تقفل المنتقي غير إنك ترسل شي منه أو تضغط نفس أيقونة
  -- الفوتر مرة ثانية (غير واضحة للمستخدم).
  dwLeft2(PICKER_TITLES[S.activePicker] or "", 12.5, x + 14, py + 7, w - 60, 18, CDm)
  if textButton("##pickerclose", x + w - 36, py + 5, 28, 22, "✕", false) then S.activePicker = nil end
  ui.setCursor(vec2(x + 6, py + 31))
  childWindowT("##pickerc", vec2(w - 12, ph - 37), function()
    if S.activePicker == "emoji" then
      local cols = 11; local cw = (w - 24) / cols
      local cx, cy = 4, 4
      for i, e in ipairs(EMOJIS) do
        local col = (i - 1) % cols
        if col == 0 and i > 1 then cy = cy + 30 end
        local xx = 4 + col * cw
        ui.setCursor(vec2(xx, cy))
        if ui.invisibleButton("##emo" .. i, vec2(cw - 4, 26)) then
          S.msgInput = (S.msgInput or "") .. e
        end
        dwBox2(e, 18, xx, cy, cw - 4, 26)
      end
    elseif S.activePicker == "stick" then
      local cols = 5
      local cw = (w - 24) / cols
      local cy = 4
      for i, u in ipairs(STICKERS) do
        local col = (i - 1) % cols
        if col == 0 and i > 1 then cy = cy + cw + 4 end
        local xx = 4 + col * cw
        ui.setCursor(vec2(xx, cy))
        local clicked = ui.invisibleButton("##pic" .. i, vec2(cw - 4, cw - 4))
        if ui.isImageReady(u) then
          pcall(function() ui.drawImage(u, vec2(xx, cy), vec2(xx + cw - 4, cy + cw - 4)) end)
        else
          pcall(function() ui.decodeImage(u) end)
          ui.drawRectFilled(vec2(xx, cy), vec2(xx + cw - 4, cy + cw - 4), rgbm(0.12,0.12,0.14,1), 8)
        end
        if clicked then sendStickerActive(u) end
      end
    elseif S.activePicker == "phr" then
      local cols = 2; local cw = (w - 24) / cols
      local cy = 4
      for i, t in ipairs(PHRASES) do
        local col = (i - 1) % cols
        if col == 0 and i > 1 then cy = cy + 40 end
        local xx = 4 + col * cw
        if textButton("##phr" .. i, xx, cy, cw - 4, 34, t, false) then
          if S.activeChannel == "general" then
            ownMsg(t, nil); pcall(function() ac.sendChatMessage(t) end); relayChatLog(t)
          elseif S.activeChannel == "clan" and S.myClan then
            clanSendChat(t, nil)
          elseif S.activeChannel == "dm" and S.activeDmWith then
            dmSend(S.activeDmWith, t, nil)
          end
          S.activePicker = nil
        end
      end
    end
  end)
  return ph + 6
end

--=================================================================
-- [19] الإرسال حسب القناة النشطة
--=================================================================
local function doSendChannel()
  local t = (S.msgInput or ""):match("^%s*(.-)%s*$")
  if t == "" then return end
  if S.activeChannel == "general" then
    local ml = t:lower()
    if ml == '/link' or ml == '/ربط' or ml == 'link/' then
      startDiscordLink()
    else
      ownMsg(t, nil)
      pcall(function() ac.sendChatMessage(t) end)
      relayChatLog(t)
    end
  elseif S.activeChannel == "clan" then
    if not S.myClan then toast("انضم لكلان أول")
    else
      -- ما نضيف الرسالة محلياً بمعرّف وهمي (كان يسبب تكرارها لما يوصل نفس
      -- الرسالة بمعرّفها الحقيقي من السيرفر عبر أول poll بعد الإرسال — تظهر
      -- مرتين). نعتمد على poll الفوري جوه clanSendChat عشان تظهر بمعرّفها
      -- الصحيح من أول مرة، بدون تكرار.
      clanSendChat(t, nil)
    end
  elseif S.activeChannel == "dm" then
    if not S.activeDmWith then toast("افتح محادثة أول")
    else
      dmSend(S.activeDmWith, t, nil)
    end
  end
  S.msgInput = ""
  S.wantFocusInput = true
end

--=================================================================
-- [20] البروفايل المنبثق
--=================================================================
local function fmtDur(sec)
  sec = math.max(0, math.floor(sec))
  local h = math.floor(sec / 3600); local m = math.floor((sec % 3600) / 60); local s = sec % 60
  if h > 0 then return h .. "س " .. m .. "د" end
  if m > 0 then return m .. "د " .. s .. "ث" end
  return s .. "ث"
end
local function fmtPlaytime(mins)
  local h = math.floor(mins / 60); local m = math.floor(mins % 60 + 0.5)
  if h > 0 then return h .. " ساعة" .. (m > 0 and (" و" .. m .. " د") or "") end
  return m .. " دقيقة"
end
local function fmtDist(m)
  if not m then return "—" end
  if m >= 1000 then return string.format("%.1f كم", m / 1000) end
  return math.floor(m + 0.5) .. " م"
end
local function fmtDateMs(ms)
  if not ms or ms == 0 then return "—" end
  local ok, s = pcall(function() return os.date("%Y-%m-%d", math.floor(ms / 1000)) end)
  return ok and s or "—"
end
local function drawModalBackdrop(winW, winH)
  ui.drawRectFilled(vec2(0, 0), vec2(winW, winH), rgbm(0, 0, 0, 0.55), 0)
end
-- الكليك اللي فتح مودال ما لازم يقفله بنفس الفريم (نفس ui.mouseClicked() يُقرأ
-- مرتين: مرة بزر الفتح، ومرة بفحص "كليك برا البطاقة" — بدون هالحارس كانت كل
-- المودالات (إدارة/كلان/بروفايل/محادثة جديدة) تفتح وتقفل بنفس الفريم فوراً).
-- الأعلام (S.xxxJustOpened) تُضبط true مباشرة (تعيين حقل، بدون دالة) بكل مكان
-- يفتح فيه المودال — بعضها معرّف بالملف قبل هالسكشن، فتفادينا الاعتماد على
-- استدعاء دالة معرّفة لاحقاً (upvalue ما يكون جاهز بعد بوقت التعريف بلغة Lua).
local function modalClickedOutside(key, mp, cx, cy, cw, ch)
  if S[key .. "JustOpened"] then S[key .. "JustOpened"] = false; return false end
  return ui.mouseClicked(ui.MouseButton.Left) and not inRect2(mp, vec2(cx, cy), vec2(cx + cw, cy + ch))
end
local function drawProfileModal(winW, winH)
  if not S.profileOpen then return end
  local m = memberByName(S.profileName)
  if not m then S.profileOpen = false; return end
  drawModalBackdrop(winW, winH)
  local cw, ch = 330, 560
  local cx, cy = 14, 14
  ui.drawRectFilled(vec2(cx, cy), vec2(cx + cw, cy + ch), rgbm(0.075, 0.07, 0.095, 1), 16)
  ui.drawRect(vec2(cx, cy), vec2(cx + cw, cy + ch), rgbm(ACC.r, ACC.g, ACC.b, 0.45), 16, nil, 1)
  ui.drawRectFilled(vec2(cx, cy), vec2(cx + cw, cy + 64), ACC, 16)
  if textButton("##profx", cx + 10, cy + 10, 34, 34, "✕", false) then S.profileOpen = false end
  drawAvatar(cx + cw - 46, cy + 64, 32, { name = m.name, avatar = m.avatar })
  local by = cy + 78
  local lvChip = (tonumber(m.level) or 0) > 0 and (" LV" .. tostring(m.level)) or ""
  dwLeft2((m.name or "?") .. (m.isMe and " (أنت)" or "") .. lvChip, 17, cx + 18, by, cw - 36, 26, CW)
  by = by + 30
  local function row(label, value, col)
    ui.drawLine(vec2(cx + 18, by + 22), vec2(cx + cw - 18, by + 22), rgbm(1,1,1,0.06), 1)
    dwLeft2(label, 12.5, cx + 18, by, 150, 20, CDm)
    ui.pushDWriteFont(FONT); ui.setCursor(vec2(cx + 18, by))
    ui.dwriteTextAligned(value or "—", 12.5, ui.Alignment.End, ui.Alignment.Center, vec2(cw - 36, 20), false, col or CW)
    ui.popDWriteFont()
    by = by + 26
  end
  row("🏆 المستوى", (tonumber(m.level) or 0) > 0 and ("LV " .. tostring(m.level) .. (m.levelTitle and (" — " .. m.levelTitle) or "")) or "جديد")
  row("👍 الإعجابات", tostring(tonumber(m.likes) or 0) .. " 👍")
  row("🟢 الحالة", "🟢 متصل الآن")
  if m.clan and m.clan ~= "" then
    if textButton("##profclan", cx + 18, by, cw - 36, 24, (m.clanEmoji or "🛡️") .. " " .. tostring(m.clan), false) then
      openClanDetails(m.clan)
    end
    by = by + 28
  else
    row("🛡️ الكلان", "بدون كلان")
  end
  row("🔗 الديسكورد", m.discord and ((type(m.discord) == 'string') and ("مرتبط ✓ " .. m.discord) or "مرتبط ✓") or "غير مرتبط ✗",
    m.discord and rgbm(0.25,0.73,0.31,1) or rgbm(0.9,0.28,0.3,1))
  row("🚗 السيارة", m.car ~= "" and m.car or "—")
  row("📅 أول دخول", fmtDateMs(m.firstSeen))
  row("🎮 إجمالي اللعب", (tonumber(m.totalMinutes) or 0) > 0 and fmtPlaytime(m.totalMinutes) or "—")
  row("⏱️ مدة التواجد", fmtDur(m.dur or 0))
  row("📍 بعده عنك", m.isMe and "—" or fmtDist(m.dist))
  row("💨 السرعة", tostring(m.speed or 0) .. " كم/س")
  by = by + 6
  dwLeft2("📝 الوصف", 12, cx + 18, by, cw - 36, 18, CDm); by = by + 20
  if m.isMe and m.discord then
    -- لازم نحدّث S.descInput من وصف العضو قبل ما نرسم صندوق الإدخال، وإلا
    -- أول فريم بعد فتح البروفايل يعرض النص القديم (من عضو/فتحة سابقة) لحظة وحدة.
    if S.descLoadedFor ~= m.name then S.descInput = m.desc or ""; S.descLoadedFor = m.name end
    local nd, _, _, boxH = arInputText("##descinput", cx + 18, by, cw - 36, 44, S.descInput, "اكتب وصفك (١٢٠ حرف)...", true, 110)
    if #nd > 120 then nd = nd:sub(1, 120) end
    S.descInput = nd
    by = by + boxH + 6
    if textButton("##savedesc", cx + 18, by, cw - 36, 30, "حفظ الوصف", true) then sendDescription(S.descInput) end
    by = by + 36
  else
    ui.pushDWriteFont(FONT); ui.setCursor(vec2(cx + 18, by))
    ui.dwriteTextAligned((m.desc and m.desc ~= "") and m.desc or "— لا يوجد وصف —", 12.5, ui.Alignment.Start, ui.Alignment.Start, vec2(cw - 36, 40), true, CW)
    ui.popDWriteFont()
    by = by + 46
  end
  by = by + 6
  if not m.isMe then
    if textButton("##proflike", cx + 18, by, (cw - 44) / 2, 34, "👍 لايك", true) then sendLike(m.name) end
    if m.discord then
      if textButton("##profmention", cx + 24 + (cw - 44) / 2, by, (cw - 44) / 2, 34, "@ منشن", true) then
        S.msgInput = (S.msgInput or "") .. "@" .. m.name .. " "; S.profileOpen = false
      end
    end
  elseif not m.discord then
    if textButton("##proflink", cx + 18, by, cw - 36, 34, "🔗 اربط حسابك بالديسكورد", true) then
      startDiscordLink(); S.profileOpen = false; toast("طلبنا لك كود الربط — بيوصلك برسالة 🔗")
    end
  end
  by = by + 42
  if textButton("##profclose", cx + 18, by, cw - 36, 30, "إغلاق", false) then S.profileOpen = false end
  -- إغلاق بالنقر خارج البطاقة
  local mp = ui.mouseLocalPos()
  if modalClickedOutside("profile", mp, cx, cy, cw, ch) then
    S.profileOpen = false
  end
end

--=================================================================
-- [21] مودال تواصل مع الإدارة
--=================================================================
local function drawAdminModal(winW, winH)
  if not S.adminOpen then return end
  drawModalBackdrop(winW, winH)
  local cw, ch = 360, 260
  local cx, cy = (winW - cw) / 2, (winH - ch) / 2
  ui.drawRectFilled(vec2(cx, cy), vec2(cx + cw, cy + ch), rgbm(0.075, 0.07, 0.095, 1), 16)
  ui.drawRect(vec2(cx, cy), vec2(cx + cw, cy + ch), rgbm(ACC.r, ACC.g, ACC.b, 0.45), 16, nil, 1)
  ui.drawRectFilled(vec2(cx, cy), vec2(cx + cw, cy + 56), ACC, 16)
  if textButton("##adminx", cx + 10, cy + 11, 34, 34, "✕", false) then S.adminOpen = false end
  dwLeft2("📨 تواصل مع الإدارة", 16, cx + 54, cy + 14, cw - 60, 28, rgbm(0.08,0.05,0.02,1))
  dwLeft2("رسالتك توصل مباشرة لروم الإدارة في الديسكورد مع اسمك.", 11.5, cx + 18, cy + 66, cw - 36, 32, CDm)
  local nt = arInputText("##admintxt", cx + 18, cy + 100, cw - 36, 70, S.adminText, "اكتب رسالتك للإدارة...", true, 70)
  S.adminText = nt
  if textButton("##adminsend", cx + 18, cy + 180, (cw - 44) / 2, 34, "إرسال 📤", true) then
    if S.adminText ~= "" then sendAdminMsg(S.adminText) end
    S.adminOpen = false; S.adminText = ""
  end
  if textButton("##admincancel", cx + 24 + (cw - 44) / 2, cy + 180, (cw - 44) / 2, 34, "إلغاء", false) then
    S.adminOpen = false; S.adminText = ""
  end
  local mp = ui.mouseLocalPos()
  if modalClickedOutside("admin", mp, cx, cy, cw, ch) then
    S.adminOpen = false
  end
end

--=================================================================
-- [22] محادثة جديدة (اختيار عضو)
--=================================================================
local function drawNewConvModal(winW, winH)
  if not S.newConvOpen then return end
  drawModalBackdrop(winW, winH)
  local cw, ch = 340, 460
  local cx, cy = (winW - cw) / 2, (winH - ch) / 2
  ui.drawRectFilled(vec2(cx, cy), vec2(cx + cw, cy + ch), rgbm(0.075, 0.07, 0.095, 1), 16)
  ui.drawRect(vec2(cx, cy), vec2(cx + cw, cy + ch), rgbm(ACC.r, ACC.g, ACC.b, 0.45), 16, nil, 1)
  if textButton("##ncx", cx + 10, cy + 10, 30, 30, "✕", false) then S.newConvOpen = false end
  dwLeft2("✨ محادثة جديدة", 14, cx + 18, cy + 48, cw - 36, 22, CW)
  local ns = arInputText("##newconvsearch", cx + 18, cy + 76, cw - 36, 26, S.newConvSearch, "ابحث عن عضو...")
  S.newConvSearch = ns
  local q = (S.newConvSearch or ""):lower()
  ui.setCursor(vec2(cx + 18, cy + 108))
  childWindowT("##ncl", vec2(cw - 36, ch - 118), function()
    local yy = 4
    for _, m in ipairs(S.members) do
      if not m.isMe and (q == "" or (m.name or ""):lower():find(q, 1, true)) then
        ui.setCursor(vec2(0, yy))
        local clicked = ui.invisibleButton("##ncrow" .. m.name, vec2(cw - 52, 42))
        local hover = ui.itemHovered()
        if hover then ui.drawRectFilled(vec2(0, yy), vec2(cw - 52, yy + 40), rgbm(1,1,1,0.06), 8); ui.setMouseCursor(ui.MouseCursor.Hand) end
        drawAvatar(20, yy + 20, 16, { name = m.name, avatar = m.avatar })
        dwLeft2(m.name or "?", 13, 42, yy + 10, cw - 100, 20, CW)
        if clicked then S.newConvOpen = false; openDm(m.name) end
        yy = yy + 44
      end
    end
  end)
  local mp = ui.mouseLocalPos()
  if modalClickedOutside("newConv", mp, cx, cy, cw, ch) then
    S.newConvOpen = false
  end
end

--=================================================================
-- [23] الكلانات — المودال الكامل (إنشاء/تعديل/دعوة/تفاصيل/إدارة)
--=================================================================
local function clanEmojiGridUI(cx, y, cw, current)
  local perRow = 6
  local cellW = (cw - 36) / perRow
  local xx, yy = 0, y
  for i, em in ipairs(CLAN_EMOJIS_ALL) do
    local col = (i - 1) % perRow
    if col == 0 and i > 1 then yy = yy + cellW + 4 end
    xx = col * cellW
    local locked = i > S.clanEmojiSlots
    local taken = false
    for _, t in ipairs(S.clanEmojisTaken) do if t == em and em ~= current then taken = true end end
    local dis = locked or taken
    local sel = em == current
    ui.setCursor(vec2(cx + 18 + xx, yy))
    local clicked = (not dis) and ui.invisibleButton("##cemo" .. i, vec2(cellW - 4, cellW - 4))
    ui.drawRectFilled(vec2(cx + 18 + xx, yy), vec2(cx + 18 + xx + cellW - 4, yy + cellW - 4),
      sel and rgbm(ACC.r, ACC.g, ACC.b, 0.9) or rgbm(0.09, 0.086, 0.118, 1), 8)
    dwBox2(locked and "🔒" or em, 16, cx + 18 + xx, yy, cellW - 4, cellW - 4, dis and rgbm(1,1,1,0.3) or CW)
    if clicked then S.clanPickEmoji = em end
  end
  return yy + cellW + 10
end
local function drawClanConfirmBar(cx, y, cw)
  if not S.clanConfirm then return y end
  ui.drawRectFilled(vec2(cx + 18, y), vec2(cx + cw - 18, y + 68), rgbm(0.14, 0.06, 0.09, 1), 10)
  ui.drawRect(vec2(cx + 18, y), vec2(cx + cw - 18, y + 68), rgbm(0.71, 0.14, 0.11, 1), 10, nil, 1)
  ui.pushDWriteFont(FONT); ui.setCursor(vec2(cx + 26, y + 8))
  ui.dwriteTextAligned(S.clanConfirm.msg, 12.5, ui.Alignment.Start, ui.Alignment.Start, vec2(cw - 52, 26), true, CW)
  ui.popDWriteFont()
  if textButton("##ccyes", cx + 26, y + 34, (cw - 60) / 2, 28, "تأكيد", false) then
    local act = S.clanConfirm.action
    S.clanConfirm = nil
    if act then act() end
  end
  if textButton("##ccno", cx + 32 + (cw - 60) / 2, y + 34, (cw - 60) / 2, 28, "إلغاء", false) then
    S.clanConfirm = nil
  end
  return y + 76
end
local function clanAsk(msg, action) S.clanConfirm = { msg = msg, action = action } end

local function drawClanModal(winW, winH)
  if not S.clanOpen then return end
  drawModalBackdrop(winW, winH)
  local cw, ch = 400, 620
  local cx, cy = (winW - cw) / 2, math.max(10, (winH - ch) / 2)
  local headCol = S.myClan and hexToColor(S.myClan.color, 1) or hexToColor(nil, 1)
  ui.drawRectFilled(vec2(cx, cy), vec2(cx + cw, cy + ch), rgbm(0.075, 0.07, 0.095, 1), 16)
  ui.drawRect(vec2(cx, cy), vec2(cx + cw, cy + ch), rgbm(headCol.r, headCol.g, headCol.b, 0.5), 16, nil, 1)
  ui.drawRectFilled(vec2(cx, cy), vec2(cx + cw, cy + 56), headCol, 16)
  if textButton("##clanx", cx + 10, cy + 11, 34, 34, "✕", false) then
    S.clanOpen = false; S.clanView = nil; S.clanScreen = "main"; S.clanConfirm = nil
  end

  ui.setCursor(vec2(cx + 10, cy + 62))
  childWindowT("##clanbodyc", vec2(cw - 20, ch - 66), function()
    local y = 6

    if S.clanView then
      local c = S.clanView
      if c.loading then
        dwBox2("جاري التحميل...", 13, 0, 40, cw - 20, 30, CDm)
        return
      end
      dwLeft2((c.emoji or "🛡️") .. " " .. tostring(c.name or "") .. "  [" .. tostring(c.tag or "") .. "]", 16, 8, y, cw - 40, 24, CW)
      y = y + 34
      local statW = (cw - 40) / 3
      local function stat(i, icon, label, val, col)
        local xx = i * statW
        ui.drawRectFilled(vec2(8 + xx, y), vec2(8 + xx + statW - 8, y + 60), rgbm(0.09,0.086,0.118,1), 10)
        dwBox2(icon, 16, 8 + xx, y + 4, statW - 8, 20)
        dwBox2(tostring(val), 15, 8 + xx, y + 22, statW - 8, 20, col or CW)
        dwBox2(label, 10, 8 + xx, y + 40, statW - 8, 16, CDm)
      end
      stat(0, "👥", "الأعضاء", c.count or 0)
      stat(1, "⭐", "المستوى", c.clanLevel or 1, rgbm(0.96,0.77,0.09,1))
      stat(2, "🎮", "ساعات", math.floor((c.clanMinutes or 0) / 60), rgbm(0.30,0.76,0.54,1))
      y = y + 70
      dwLeft2("👑 المالك: " .. tostring(c.owner or "؟"), 12.5, 8, y, cw - 40, 18, CDm); y = y + 22
      dwLeft2("📅 أُنشئ: " .. fmtDateMs(c.created), 12.5, 8, y, cw - 40, 18, CDm); y = y + 22
      if c.desc and c.desc ~= "" then
        ui.drawRectFilled(vec2(8, y), vec2(cw - 32, y + 44), rgbm(0.09,0.086,0.118,1), 8)
        ui.pushDWriteFont(FONT); ui.setCursor(vec2(14, y + 6))
        ui.dwriteTextAligned(c.desc, 12, ui.Alignment.Start, ui.Alignment.Start, vec2(cw - 44, 34), true, CW)
        ui.popDWriteFont()
        y = y + 52
      end
      dwLeft2("👥 الأعضاء (" .. (c.count or 0) .. ")", 12, 8, y, cw - 40, 18, CDm); y = y + 22
      for _, mm in ipairs(c.members or {}) do
        ui.drawRectFilled(vec2(8, y), vec2(cw - 32, y + 38), rgbm(0.09,0.086,0.118,1), 8)
        dwLeft2(tostring(mm.name or "?"), 12.5, 46, y + 4, cw - 90, 18, CW)
        if mm.isOwner then dwLeft2("👑 قائد", 10.5, 46, y + 20, 100, 14, rgbm(0.96,0.77,0.09,1))
        elseif mm.isCoLeader then dwLeft2("🛡️ مساعد", 10.5, 46, y + 20, 100, 14, rgbm(0.23,0.51,0.96,1)) end
        drawAvatar(24, y + 19, 14, { name = mm.name })
        y = y + 42
      end
      y = y + 8
      if textButton("##clanviewclose", 8, y, cw - 32, 32, "إغلاق", false) then S.clanOpen = false; S.clanView = nil end
      return
    end

    if S.clanScreen == "invite" and S.myClan then
      dwLeft2("➕ دعوة لاعب", 15, 8, y, cw - 40, 22, CW); y = y + 30
      dwLeft2("اختر لاعب متصل بدون كلان لدعوته:", 12, 8, y, cw - 40, 18, CDm); y = y + 24
      local ns = arInputText("##invsearch", 8, y, cw - 16, 26, S.clanInviteSearch, "🔍 ابحث...")
      S.clanInviteSearch = ns; y = y + 34
      local q = (S.clanInviteSearch or ""):lower()
      local myMembers = {}
      for _, mm in ipairs(S.myClan.members or {}) do myMembers[(mm.name or ""):lower()] = true end
      for _, m in ipairs(S.members) do
        if not m.srv and not m.isMe and (not m.clan or m.clan == "" ) and not myMembers[(m.name or ""):lower()]
          and (q == "" or (m.name or ""):lower():find(q, 1, true)) then
          ui.drawRectFilled(vec2(8, y), vec2(cw - 32, y + 40), rgbm(0.09,0.086,0.118,1), 9)
          drawAvatar(24, y + 20, 13, { name = m.name })
          dwLeft2(m.name or "?", 12.5, 44, y + 10, cw - 140, 18, CW)
          if textButton("##invd" .. m.name, cw - 100, y + 6, 70, 28, "دعوة", true) then
            clanPost('/drive/clan/invite', { targetName = m.name }, 'تم إرسال الدعوة 📩')
          end
          y = y + 46
        end
      end
      y = y + 6
      if textButton("##clanbackinv", 8, y, cw - 32, 30, "رجوع", false) then S.clanScreen = "main" end
      return
    end

    if S.clanScreen == "edit" and S.myClan then
      dwLeft2("✏️ تعديل الكلان", 15, 8, y, cw - 40, 22, CW); y = y + 32
      dwLeft2("📝 الوصف", 12, 8, y, cw - 40, 16, CDm); y = y + 18
      local nd, _, _, ndBoxH = arInputText("##editdesc", 8, y, cw - 16, 56, S.clanEditDesc, "وصف الكلان...", true, 110)
      if #nd > 120 then nd = nd:sub(1, 120) end
      S.clanEditDesc = nd; y = y + ndBoxH + 8
      dwLeft2("🎨 لون الكلان", 12, 8, y, cw - 40, 16, CDm); y = y + 20
      for i, pc in ipairs(CLAN_COLOR_PRESETS) do
        local xx = 8 + (i - 1) * 40
        local on = pc:lower() == (S.clanPickColor or ""):lower()
        ui.setCursor(vec2(xx, y))
        local clicked = ui.invisibleButton("##epc" .. i, vec2(34, 34))
        ui.drawRectFilled(vec2(xx, y), vec2(xx + 34, y + 34), hexToColor(pc, 1), 9)
        if on then ui.drawRect(vec2(xx, y), vec2(xx + 34, y + 34), CW, 9, nil, 2) end
        if clicked then S.clanPickColor = pc end
      end
      y = y + 44
      if S.myClan.customColor then
        dwLeft2("✨ لون حر (اسحب لاختيار اللون)", 11.5, 8, y, cw - 40, 16, rgbm(0.96,0.77,0.09,1)); y = y + 20
        ui.setCursor(vec2(8, y))
        local nh, chg = ui.slider("##huee", S.clanPickHue, 0, 360, "%.0f")
        if chg then S.clanPickHue = nh; S.clanPickColor = hslToHex(nh, 70, 50) end
        y = y + 30
      else
        dwLeft2("🔒 لون حر يُفتح بمستوى 8", 11, 8, y, cw - 40, 16, CDm); y = y + 24
      end
      dwLeft2((S.myClan.emoji or "🛡️") .. " إيموجي الكلان", 12, 8, y, cw - 40, 16, CDm); y = y + 20
      y = clanEmojiGridUI(0, y, cw, S.clanPickEmoji)
      if textButton("##clansave", 8, y, cw - 32, 32, "حفظ", true) then
        local ei = 0
        for i, e in ipairs(CLAN_EMOJIS_ALL) do if e == S.clanPickEmoji then ei = i - 1 end end
        clanPost('/drive/clan/edit', { desc = S.clanEditDesc, color = S.clanPickColor, emojiIdx = ei }, 'تم الحفظ')
      end
      y = y + 40
      if textButton("##clanbackedit", 8, y, cw - 32, 30, "رجوع", false) then S.clanScreen = "main" end
      return
    end

    if not S.myClanLoaded then
      dwBox2("جاري التحميل...", 13, 0, 40, cw - 20, 30, CDm)
      return
    end

    if not S.myClan then
      dwLeft2("🛡️ الكلانات", 15, 8, y, cw - 40, 22, CW); y = y + 30
      if #S.invites > 0 then
        dwLeft2("📩 دعواتك (" .. #S.invites .. ")", 12, 8, y, cw - 40, 18, CDm); y = y + 22
        for _, iv in ipairs(S.invites) do
          ui.drawRectFilled(vec2(8, y), vec2(cw - 32, y + 40), rgbm(0.09,0.086,0.118,1), 9)
          dwLeft2(tostring(iv.name) .. " [" .. tostring(iv.tag or "") .. "] · من " .. tostring(iv.byName or ""), 11.5, 14, y + 10, cw - 160, 18, CW)
          if textButton("##ivacc" .. tostring(iv.clanId), cw - 140, y + 6, 60, 28, "قبول", true) then
            clanPost('/drive/clan/respond', { clanId = iv.clanId, accept = true }, 'انضممت للكلان ✅')
          end
          if textButton("##ivrej" .. tostring(iv.clanId), cw - 74, y + 6, 34, 28, "✕", false) then
            clanPost('/drive/clan/respond', { clanId = iv.clanId, accept = false }, 'تم الرفض')
          end
          y = y + 46
        end
        y = y + 8
      end
      if not S.canCreate then
        ui.drawRectFilled(vec2(8, y), vec2(cw - 32, y + 100), rgbm(0.10, 0.07, 0.09, 1), 12)
        dwBox2("🔒", 24, 8, y + 8, cw - 40, 32)
        dwBox2("ليس لديك صلاحية إنشاء كلان", 13, 8, y + 44, cw - 40, 20, CW)
        dwBox2("هذه الميزة محصورة على رتب معينة", 11, 8, y + 66, cw - 40, 18, CDm)
        return
      end
      dwLeft2("✨ إنشاء كلان جديد", 13, 8, y, cw - 40, 18, CDm); y = y + 24
      local nn = arInputText("##clanname", 8, y, cw - 16, 26, S.clanCreateName, "اسم الكلان (2-20)")
      if #nn > 20 then nn = nn:sub(1,20) end
      S.clanCreateName = nn; y = y + 34
      local nt = arInputText("##clantag", 8, y, cw - 16, 26, S.clanCreateTag, "التاق (2-5)")
      if #nt > 5 then nt = nt:sub(1,5) end
      S.clanCreateTag = nt; y = y + 38
      dwLeft2("🎨 اللون:", 12, 8, y, cw - 40, 16, CDm); y = y + 20
      for i, pc in ipairs(CLAN_COLOR_PRESETS) do
        local xx = 8 + (i - 1) * 40
        local on = pc:lower() == (S.clanPickColor or ""):lower()
        ui.setCursor(vec2(xx, y))
        local clicked = ui.invisibleButton("##npc" .. i, vec2(34, 34))
        ui.drawRectFilled(vec2(xx, y), vec2(xx + 34, y + 34), hexToColor(pc, 1), 9)
        if on then ui.drawRect(vec2(xx, y), vec2(xx + 34, y + 34), CW, 9, nil, 2) end
        if clicked then S.clanPickColor = pc end
      end
      y = y + 44
      dwLeft2("اختر إيموجي:", 12, 8, y, cw - 40, 16, CDm); y = y + 20
      y = clanEmojiGridUI(0, y, cw, S.clanPickEmoji)
      if textButton("##clancreate", 8, y, cw - 32, 34, "إنشاء الكلان 🛡️", true) then
        if S.clanCreateName == "" then toast("اكتب اسم الكلان")
        else
          local ei = 0
          for i, e in ipairs(CLAN_EMOJIS_ALL) do if e == S.clanPickEmoji then ei = i - 1 end end
          clanPost('/drive/clan/create', { clanName = S.clanCreateName, tag = S.clanCreateTag, color = S.clanPickColor, emojiIdx = ei }, 'تم إنشاء الكلان')
        end
      end
      return
    end

    -- عندي كلان: العرض الرئيسي
    local col = hexToColor(S.myClan.color, 1)
    dwLeft2((S.myClan.emoji or "🛡️") .. " " .. tostring(S.myClan.name) .. "  [" .. tostring(S.myClan.tag or "") .. "]", 16, 8, y, cw - 40, 24, CW)
    y = y + 34
    local statW = (cw - 40) / 3
    local function stat(i, icon, label, val, c2)
      local xx = i * statW
      ui.drawRectFilled(vec2(8 + xx, y), vec2(8 + xx + statW - 8, y + 60), rgbm(0.09,0.086,0.118,1), 10)
      dwBox2(icon, 16, 8 + xx, y + 4, statW - 8, 20)
      dwBox2(tostring(val), 15, 8 + xx, y + 22, statW - 8, 20, c2 or CW)
      dwBox2(label, 10, 8 + xx, y + 40, statW - 8, 16, CDm)
    end
    stat(0, "👥", "الأعضاء", (S.myClan.count or 0) .. "/" .. (S.myClan.maxMembers or 5))
    stat(1, "⭐", "المستوى", S.myClan.clanLevel or 1, rgbm(0.96,0.77,0.09,1))
    stat(2, "🎮", "ساعات", math.floor((S.myClan.clanMinutes or 0) / 60), rgbm(0.30,0.76,0.54,1))
    y = y + 70
    dwLeft2("👑 المالك: " .. tostring(S.myClan.owner or "؟") .. (S.isOwner and " (أنت)" or ""), 12.5, 8, y, cw - 40, 18, CDm); y = y + 22
    dwLeft2("🏅 اللقب: " .. tostring(S.myClan.levelTitle or "مبتدئ"), 12.5, 8, y, cw - 40, 18, rgbm(0.96,0.77,0.09,1)); y = y + 22
    if S.myClan.desc and S.myClan.desc ~= "" then
      ui.drawRectFilled(vec2(8, y), vec2(cw - 32, y + 44), rgbm(0.09,0.086,0.118,1), 8)
      ui.pushDWriteFont(FONT); ui.setCursor(vec2(14, y + 6))
      ui.dwriteTextAligned(S.myClan.desc, 12, ui.Alignment.Start, ui.Alignment.Start, vec2(cw - 44, 34), true, CW)
      ui.popDWriteFont()
      y = y + 52
    end
    dwLeft2("👥 الأعضاء (" .. (S.myClan.count or 0) .. ")", 12, 8, y, cw - 40, 18, CDm); y = y + 22
    local canManage = S.isOwner or S.isCoLeader
    for _, mm in ipairs(S.myClan.members or {}) do
      ui.drawRectFilled(vec2(8, y), vec2(cw - 32, y + 40), rgbm(0.09,0.086,0.118,1), 8)
      drawAvatar(24, y + 20, 14, { name = mm.name })
      dwLeft2(tostring(mm.name or "?"), 12.5, 46, y + 4, 140, 18, CW)
      if mm.isOwner then dwLeft2("👑 قائد", 10.5, 46, y + 20, 100, 14, rgbm(0.96,0.77,0.09,1))
      elseif mm.isCoLeader then dwLeft2("🛡️ مساعد", 10.5, 46, y + 20, 100, 14, rgbm(0.23,0.51,0.96,1)) end
      if canManage and not mm.isOwner then
        local bx = cw - 40
        if S.isOwner then
          bx = bx - 30
          if textButton("##kick" .. mm.name, bx, y + 6, 26, 28, "✕", false) then
            clanAsk("طرد " .. mm.name .. " من الكلان؟", function() clanPost('/drive/clan/kick', { targetName = mm.name }, 'تم الطرد') end)
          end
          bx = bx - 34
          if textButton("##xfer" .. mm.name, bx, y + 6, 30, 28, "👑", false) then
            clanAsk("نقل ملكية الكلان لـ " .. mm.name .. "؟", function() clanPost('/drive/clan/transfer', { targetName = mm.name }, 'تم نقل الملكية 👑') end)
          end
          bx = bx - 34
          if mm.isCoLeader then
            if textButton("##dem" .. mm.name, bx, y + 6, 30, 28, "⬇️", false) then
              clanAsk("تنزيل " .. mm.name .. " من قائد مساعد؟", function() clanPost('/drive/clan/coleader', { targetName = mm.name, promote = false }, 'تم التنزيل ⬇️') end)
            end
          else
            if textButton("##pro" .. mm.name, bx, y + 6, 30, 28, "⬆️", false) then
              clanAsk("ترقية " .. mm.name .. " لقائد مساعد؟", function() clanPost('/drive/clan/coleader', { targetName = mm.name, promote = true }, 'تمت الترقية لقائد مساعد ⬆️') end)
            end
          end
        elseif S.isCoLeader and not mm.isCoLeader then
          if textButton("##kick2" .. mm.name, bx - 30, y + 6, 26, 28, "✕", false) then
            clanAsk("طرد " .. mm.name .. " من الكلان؟", function() clanPost('/drive/clan/kick', { targetName = mm.name }, 'تم الطرد') end)
          end
        end
      end
      y = y + 44
    end
    y = y + 8
    if S.isOwner or S.isCoLeader then
      if textButton("##claninvitebtn", 8, y, cw - 32, 32, "➕ دعوة", true) then S.clanScreen = "invite" end
      y = y + 38
    end
    if S.isOwner then
      if textButton("##claneditbtn", 8, y, (cw - 40) / 2, 32, "✏️ تعديل", false) then
        S.clanScreen = "edit"; S.clanEditDesc = S.myClan.desc or ""
        S.clanPickColor = S.myClan.color or "#F7820E"; S.clanPickEmoji = S.myClan.emoji or S.clanPickEmoji
        S.clanPickHue = 30
      end
      if textButton("##candelbtn", 16 + (cw - 40) / 2, y, (cw - 40) / 2, 32, "🗑️ حذف", false) then
        clanAsk("حذف الكلان نهائياً؟ لا يمكن التراجع.", function() clanPost('/drive/clan/delete', {}, 'تم حذف الكلان') end)
      end
      y = y + 38
    else
      if textButton("##clanleavebtn", 8, y, cw - 32, 32, "🚪 مغادرة", false) then
        clanAsk("مغادرة الكلان؟", function() clanPost('/drive/clan/leave', {}, 'غادرت الكلان') end)
      end
      y = y + 38
    end
    y = drawClanConfirmBar(0, y, cw)
  end)
  if S.clanJustOpened then
    S.clanJustOpened = false -- الكليك اللي فتح النافذة هذا الفريم — ما نقفلها بنفس الفريم
  else
    local mp = ui.mouseLocalPos()
    if ui.mouseClicked(ui.MouseButton.Left) and not inRect2(mp, vec2(cx, cy), vec2(cx + cw, cy + ch)) and not S.clanConfirm then
      S.clanOpen = false; S.clanView = nil; S.clanScreen = "main"
    end
  end
end
local function openClanPanel()
  S.clanPickColor = "#F7820E"; S.clanView = nil; S.clanScreen = "main"; S.myClanLoaded = false
  S.clanOpen = true
  S.clanJustOpened = true
  clanFetchMine(); clanFetchEmojis()
end

--=================================================================
-- [24] التوست
--=================================================================
local function drawToast(winW, winH)
  if not S.toastText or S.clock > S.toastUntil then return end
  local w = math.min(400, math.ceil(ui.measureDWriteText(S.toastText, 14, 360).x) + 40)
  local x = (winW - w) / 2
  local y = winH - 80
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + 40), rgbm(0.06, 0.055, 0.07, 0.96), 12)
  ui.drawRect(vec2(x, y), vec2(x + w, y + 40), rgbm(ACC.r, ACC.g, ACC.b, 0.5), 12, nil, 1)
  dwBox2(S.toastText, 13, x, y, w, 40, CW)
end

--=================================================================
-- [25] الرسم الرئيسي لنافذة الشات
--=================================================================
local function drawChatWindow()
  local sim = ac.getSim()
  if not sim then return end

  if not S.pos then
    if cStor.dc_posX >= 0 and cStor.dc_posY >= 0 then S.pos = vec2(cStor.dc_posX, cStor.dc_posY)
    else S.pos = vec2((sim.windowWidth - S.W) * 0.5, (sim.windowHeight - S.H) * 0.5) end
  end
  S.pos.x = math.max(-S.W + 80, math.min(S.pos.x, sim.windowWidth - 80))
  S.pos.y = math.max(0, math.min(S.pos.y, sim.windowHeight - 60))

  local cmp = ui.mousePos()
  local clp = cmp - S.pos
  local cClicked = ui.mouseClicked(ui.MouseButton.Left)
  local overlayActive = S.profileOpen or S.adminOpen or S.newConvOpen or S.clanOpen
  if cClicked and not S.dragging and not overlayActive and inRect2(clp, vec2(300, 0), vec2(S.W, 56)) then
    S.dragging = true; S.dragOff = clp:clone()
  end
  if S.dragging then
    if ui.mouseDown(ui.MouseButton.Left) then
      S.pos = cmp - S.dragOff
      S.pos.x = math.max(0, math.min(sim.windowWidth - S.W, S.pos.x))
      S.pos.y = math.max(0, math.min(sim.windowHeight - S.H, S.pos.y))
    else
      S.dragging = false
      cStor.dc_posX = S.pos.x; cStor.dc_posY = S.pos.y
    end
  end

  ui.transparentWindow('driveChatNative', S.pos, vec2(S.W, S.H), true, true, function()
    local W, H = S.W, S.H
    -- شلنا خيار شفافية الخلفية القابلة للتعديل نهائياً — كانت تفتح مشاكل رسم
    -- متلاحقة (خلفية ChildBg، خطوط صناديق الكتابة الداخلية، تباين الألوان)
    -- كل ما تصير الخلفية شبه-شفافة، بدون أي فايدة توازي هالصداع. البقية
    -- (BGA/S.bgAlpha) خليناها بالكود عشان دوال الرسم الثانية (سايدبار
    -- الأعضاء/القنوات) لسا تستخدم نفس المتغير، بس قيمتها ثابتة معتّمة كاملة.
    local BGA = 1
    S.bgAlpha = BGA -- متاحة لدوال الرسم الثانية (سايدبار الأعضاء/القنوات) عبر S
    ui.drawRectFilled(vec2(0, 0), vec2(W, H), rgbm(0.078, 0.075, 0.094, BGA), 18)
    ui.drawRect(vec2(0, 0), vec2(W, H), rgbm(ACC.r, ACC.g, ACC.b, math.max(0.06, 0.35 * BGA)), 18, nil, 1)

    -- ===== الهيدر =====
    -- مهم: كل الأزرار لازم تكون بأول 300px (يسار) — منطقة سحب النافذة تبدأ من
    -- x=300 (تحت)، ونفس القاعدة اللي كانت بالنسخة القديمة (CEF) لتفادي إن
    -- الضغط على زر يُقرأ كبداية سحب للنافذة بنفس الوقت.
    -- هيدر داكن (بدل الشريط البرتقالي الصريح المسطّح اللي كان يحس اللاعب إنه
    -- بواجهة قديمة) + خط توهج تدريجي بالأسفل بلون البراند — نفس فكرة الـ glow
    -- المستخدمة بواجهات الألعاب الحديثة، مبني بس من مستطيلات متراكبة بعتامة
    -- متدرجة (ما نعتمد على أي دالة تدرّج غير مؤكدة بـ CSP).
    ui.drawRectFilled(vec2(0, 0), vec2(W, 56), rgbm(0.055, 0.048, 0.062, 1), 18)
    ui.drawRectFilled(vec2(0, 28), vec2(W, 56), rgbm(0.055, 0.048, 0.062, 1), 0)
    ui.drawRectFilled(vec2(0, 47), vec2(W, 50), rgbm(ACC.r, ACC.g, ACC.b, 0.16), 0)
    ui.drawRectFilled(vec2(0, 50), vec2(W, 53), rgbm(ACC.r, ACC.g, ACC.b, 0.4), 0)
    ui.drawRectFilled(vec2(0, 53), vec2(W, 56), rgbm(ACC.r, ACC.g, ACC.b, 1), 0)
    local bx = 8
    if iconButton("##xbtn", bx, 10, 34, 36, "✕", false) then closeChat() end
    bx = bx + 40
    -- بقية أزرار الهيدر (إشعارات/كلان/إدارة) تتعطّل تماماً وقت فتح أي مودال —
    -- عشان ما تفتح مودال ثاني فوق الأول وتصير الواجهة متداخلة (نفس سبب مشكلة
    -- "الشات يضرب" اللي صارت وقت فتح البروفايل وغيره).
    if not overlayActive then
      if iconButton("##notifbtn", bx, 10, 34, 36, cStor.dc_notif and "🔔" or "🔕", cStor.dc_notif) then
        cStor.dc_notif = not cStor.dc_notif
        toast(cStor.dc_notif and "فقاعات الإشعارات: تشتغل لما تسكّر الشات 🔔" or "فقاعات الإشعارات: مقفلة 🔕")
      end
      bx = bx + 40
      if iconButton("##clanbtn", bx, 10, 34, 36, "🛡️", S.clanOpen) then openClanPanel() end
      bx = bx + 40
      if ADMIN_WEBHOOK ~= "" then
        if iconButton("##adminbtn", bx, 10, 34, 36, "📨", S.adminOpen) then S.adminOpen = true; S.adminJustOpened = true end
        bx = bx + 40
      end
    end
    -- الشعار/العنوان بمنطقة السحب (يمين) — نص فقط، بدون عناصر تفاعلية
    dwLeft2("DRIVE", 20, W - 210, 8, 90, 40, ACC)
    dwLeft2("الشات 💬", 15, W - 118, 14, 110, 30, CY)

    -- ===== شريط التلميح =====
    dwBox2("للإرسال ENTER · للإغلاق ESC أو ✕ · اضغط أي عضو لعرض حسابه · اكتب /link لربط الديسكورد", 11.5, 0, 60, W, 18, CDm)

    -- ===== الجسم =====
    local bodyY = 84
    local footH = 56
    local pickerReserve = S.activePicker and 176 or 0
    local bodyH = H - bodyY - footH - pickerReserve - 8
    local sideW = 208
    local chW = 216
    local midX = sideW + 12
    local midW = W - sideW - chW - 24

    -- كل جسم الشات (سايدبار الأعضاء/سجل الرسائل/سايدبار القنوات/المنتقي/الفوتر)
    -- يتعطّل بالكامل وقت فتح أي مودال — الخلفية المعتّمة (drawModalBackdrop)
    -- كانت مجرد رسم مربع شفاف بدون أي حجب فعلي للنقر، فكان ممكن تضغط على
    -- عضو/زر خلف المودال وتفتح مودال ثاني فوقه (تداخل + "ضرب" بالواجهة).
    -- الآن الجسم كامل ما يُرسم ولا يُعالج نقر إطلاقاً طول ما فيه مودال مفتوح.
    if not overlayActive then
      drawMemberSidebar(6, bodyY, sideW, bodyH)

      -- سجل الرسائل الأوسط حسب القناة النشطة
      ui.drawRectFilled(vec2(midX, bodyY), vec2(midX + midW, bodyY + bodyH), rgbm(0.09, 0.086, 0.106, BGA), 12)
      ui.drawRect(vec2(midX, bodyY), vec2(midX + midW, bodyY + bodyH), rgbm(1,1,1,0.06 * BGA), 12, nil, 1)
      if S.activeChannel == "general" then
        local fsb = S.newGeneral; S.newGeneral = false
        renderMsgList("##genlog", midX + 6, bodyY + 6, midW - 12, bodyH - 12, S.log, function(m) return m.mine end, function(nm) S.profileOpen = true; S.profileName = nm; S.descLoadedFor = nil; S.profileJustOpened = true end, fsb)
      elseif S.activeChannel == "clan" then
        local fsb = S.newClan; S.newClan = false
        renderMsgList("##clanlog", midX + 6, bodyY + 6, midW - 12, bodyH - 12, S.clanLog, function(m) return m.name == myName() end, function(nm) S.profileOpen = true; S.profileName = nm; S.descLoadedFor = nil; S.profileJustOpened = true end, fsb)
      else
        if S.activeDmWith then
          local fsb = S.newDm; S.newDm = false
          renderMsgList("##dmlog", midX + 6, bodyY + 6, midW - 12, bodyH - 12, S.dmMsgs[S.activeDmWith] or {}, function(m) return m.name == myName() end, nil, fsb)
        else
          dwBox2("اختر محادثة من القائمة →", 13, midX, bodyY + bodyH / 2 - 12, midW, 24, CDm)
        end
      end

      drawChannelSidebar(midX + midW + 12, bodyY, chW, bodyH)

      -- ===== منتقي الملصقات (لو مفتوح) =====
      local footY = H - footH - 8
      drawPickerPanel(6, footY, W - 12)

      -- ===== الفوتر =====
      local pw = 40
      local px = 8
      if iconButton("##pemoji", px, footY, pw, footH - 8, "😀", S.activePicker == "emoji") then
        S.activePicker = (S.activePicker == "emoji") and nil or "emoji"
      end
      px = px + pw + 6
      if iconButton("##pstick", px, footY, pw, footH - 8, "🖼️", S.activePicker == "stick") then
        S.activePicker = (S.activePicker == "stick") and nil or "stick"
      end
      px = px + pw + 6
      if iconButton("##pphr", px, footY, pw, footH - 8, "💬", S.activePicker == "phr") then
        S.activePicker = (S.activePicker == "phr") and nil or "phr"
      end
      px = px + pw + 10
      local sendW = 50
      local inputW = W - px - sendW - 14
      if S.wantFocusInput then ui.setKeyboardFocusHere(); S.wantFocusInput = false end
      local placeholderTxt = S.activeChannel == "dm" and (S.activeDmWith and ("رسالة إلى " .. S.activeDmWith .. "...") or "افتح محادثة أول...")
        or (S.activeChannel == "clan" and "رسالة لأعضاء الكلان..." or "اكتب رسالتك هنا...")
      local nmsg, mchg, mentered = arInputText("##msgin", px, footY, inputW, footH - 8, S.msgInput, placeholderTxt)
      S.msgInput = nmsg
      if mentered then doSendChannel() end
      if textButton("##sendbtn", px + inputW + 8, footY, sendW, footH - 8, "➤", true) then doSendChannel() end
    end

    -- ===== المودالات (فوق كل شي) =====
    drawProfileModal(W, H)
    drawAdminModal(W, H)
    drawNewConvModal(W, H)
    drawClanModal(W, H)
    drawToast(W, H)
    -- ملاحظة: لا نستدعي ui.captureKeyboard() هنا عمداً. كانت موجودة بالنسخة
    -- القديمة عشان تلتقط ضغطات المفاتيح يدوياً وتمررها لمتصفح CEF (اللي ما
    -- عنده وصول تلقائي لدخل الكيبورد). حقول ui.inputText الأصلية تتولى فوكس/كتابة
    -- الكيبورد بنفسها عبر ImGui — استدعاء captureKeyboard هنا كان يسحب التركيز
    -- منها ويسبب مشاكل كتابة (حروف تضيع/ما تنكتب) بصندوق الرسالة وكل الحقول.
  end)

  if cClicked and not S.dragging and not overlayActive and not inRect2(clp, vec2(0, 0), vec2(S.W, S.H)) then
    closeChat()
  end
  if ac.isKeyDown(ui.KeyIndex.Escape) then
    if overlayActive then
      S.profileOpen = false; S.adminOpen = false; S.newConvOpen = false
      if S.clanOpen then if S.clanView then S.clanView = nil elseif S.clanScreen ~= "main" then S.clanScreen = "main" else S.clanOpen = false end end
    else
      closeChat()
    end
  end
end

--=================================================================
-- [26] إخفاء شات AC الأصلي (يعاد تطبيقه دورياً)
--=================================================================
local function hideVanillaChat(now)
  pcall(function()
    if not S.vanillaWin then
      if now - (S.vanillaTry or -10) < 3 then return end
      S.vanillaTry = now
      for _, nm in ipairs({ 'Chat', 'chat', 'AC_CHAT', 'ac_chat', 'CHAT' }) do
        local w = ac.accessAppWindow(nm)
        if w and w:valid() then S.vanillaWin = w; break end
      end
    end
    local w = S.vanillaWin
    if w and w:valid() and (not S.vanillaHidden or now >= (S.vanillaAt or 0)) then
      w:setVisible(false)
      w:resize(vec2(1, 1))
      w:move(vec2(99999, 99999))
      pcall(function() w:setRedirectLayer(99) end)
      S.vanillaHidden = true
      S.vanillaAt = now + 5
    end
  end)
end

--=================================================================
-- [27] تحديث دوري (رتب/أعضاء/رسائل)
--=================================================================
local function periodicUpdate(sim, now)
  if RANKS_URL ~= "" and (now - S.lastRanks) > 10 then
    S.lastRanks = now
    fetchRanks()
  end
  -- كل ما الشات مفتوح نسحب رسائل الكلان/الخاص بفاصل قصير — بغض النظر عن أي
  -- تبويب مفتوح حالياً (قبل كانت مقيدة بتبويب الكلان/الخاص فقط بفاصل ٤ ثواني،
  -- فكانت رسائل الكلان ما توصل إلا لو فاتح نفس التبويب، وبتأخير محسوس).
  if S.open and RANKS_URL ~= "" and (now - S.lastMsgPoll) > 1.5 then
    S.lastMsgPoll = now
    pollMessages()
  end
  if (now - S.lastPush) > 1 then
    S.lastPush = now
    pcall(function()
      local my = ac.getCar(0)
      local list, seen = {}, {}
      for i = 0, (sim.carsCount or 0) - 1 do
        local car = ac.getCar(i)
        local nm = ac.getDriverName(i) or ("لاعب " .. i)
        if car and car.isConnected and not car.isAIControlled and not string.find(nm, "Traffic") then
          local jk = i .. '|' .. nm
          if not S.joined[jk] then
            S.joined[jk] = now
            if now - (S.lastRanks or 0) > 3 then S.lastRanks = now - 10 end
          end
          seen[jk] = true
          local r = S.ranks[nm]
          local d = 0
          if my and i ~= 0 then d = (car.position - my.position):length() end
          local carName = ''
          pcall(function() carName = ac.getCarName(i) or '' end)
          list[#list + 1] = {
            name = nm, isMe = (i == 0), status = 'on', rank = rankOf(nm),
            rankColor = (r and r.color) or false, discord = (r and r.discord) or false,
            avatar = (r and r.avatar) or nil, car = carName,
            dur = math.floor(now - S.joined[jk]), dist = math.floor(d), speed = math.floor(car.speedKmh or 0),
            level = (r and r.level) or 0, levelTitle = (r and r.levelTitle) or false,
            totalMinutes = (r and r.totalMinutes) or 0, firstSeen = (r and r.firstSeen) or false,
            desc = (r and r.desc) or false, likes = (r and r.likes) or 0,
            clan = (r and r.clan) or false, clanTag = (r and r.clanTag) or false,
            clanColor = (r and r.clanColor) or false, clanEmoji = (r and r.clanEmoji) or false,
          }
        end
      end
      for k in pairs(S.joined) do if not seen[k] then S.joined[k] = nil end end
      S.members = list
    end)
  end
end

--=================================================================
-- [28] script.update / script.drawUI
--=================================================================
script.update = function(dt)
  S.clock = S.clock + dt
  local sim = ac.getSim()
  if sim then hideVanillaChat(S.clock); periodicUpdate(sim, S.clock) end

  if not S.open then
    local canCap = true
    if type(ui.wantCaptureKeyboard) == "function" and ui.wantCaptureKeyboard() then canCap = false end
    if type(ac.isChatOpen) == "function" and ac.isChatOpen() then canCap = false end
    local dn = ui.keyboardButtonDown(KEY)
    if dn and not S.prevKey and canCap then openChat() end
    S.prevKey = dn
  else
    S.prevKey = false
  end
  -- ملاحظة: ما نعتمد على متغير global زي "chatTyping" يعبر بين السكربتات —
  -- كل سكربت SCRIPT_X منفصل يشتغل بـ Lua VM معزولة تماماً، فأي global هنا ما
  -- ينوصل لملف admin_menu.lua إطلاقاً. اللي فعلاً يعبر بين السكربتات (لأنه
  -- نداء حقيقي لمحرك اللعبة، مو متغير Lua) هو ac.setCurrentInputMethod تحت.
  -- "S.chatTyping" (يتصفّر أول كل فريم برسم بـ script.drawUI، ويترفع true
  -- من جوا arInputText أي صندوق كتابة يصير فيه فوكس) تتبّع داخلي بهذا
  -- الملف بس، نستخدمه عشان نعيد تأكيد نداء ac.setCurrentInputMethod من أكثر
  -- من نقطة (هنا وبأول drawUI) — تقليلاً لأي احتمال فرق ترتيب/فريم بين
  -- تشغيل سكربتنا وسكربت منيو الإدمن كل فريم.

  if S.open then
    if not S.inputSaved then
      S.inputSaved = true
      pcall(function() if ac.getCurrentInputMethod then S.savedInput = ac.getCurrentInputMethod() end end)
    end
    pcall(function()
      if ac.setCurrentInputMethod and ac.UserInputMode then ac.setCurrentInputMethod(ac.UserInputMode.UI) end
    end)
  elseif (not S.open) and S.inputSaved then
    S.inputSaved = false
    pcall(function()
      if ac.setCurrentInputMethod then
        if S.savedInput ~= nil then ac.setCurrentInputMethod(S.savedInput)
        elseif ac.UserInputMode and ac.UserInputMode.Game then ac.setCurrentInputMethod(ac.UserInputMode.Game) end
      end
    end)
  end
end

script.drawUI = function()
  if S.open then
    -- نفس تأكيد وضع الإدخال اللي بـ script.update، بس هنا كمان (نهاية
    -- الفريم مقابل بدايته) — عشان أي سكربت ثاني يقرأ الحالة بلحظة مختلفة
    -- بنفس الفريم يشوف "UI" مؤكدة، مو بس أول الفريم.
    pcall(function()
      if ac.setCurrentInputMethod and ac.UserInputMode then ac.setCurrentInputMethod(ac.UserInputMode.UI) end
    end)
  end
  S.chatTyping = false
  local sim = ac.getSim()
  pcall(function() drawChatLog(sim) end)
  if S.open then
    local ok, err = pcall(drawChatWindow)
    if not ok and not S.errLogged then S.errLogged = true; ac.log("drive_chat_native draw error: " .. tostring(err)) end
  end
end

-- تسجيل اختياري بقائمة "أونلاين إكسترا" الخاصة بـ CSP
pcall(function()
  ui.registerOnlineExtra("DRIVE Chat", function()
    if S.open then closeChat() else openChat() end
  end)
end)

ac.log("[drive_chat_native] loaded OK — native ImGui edition (no WebBrowser/CEF dependency)")

end)
if not __ok then
  ac.log("[drive_chat_native] load FAILED: " .. tostring(__err))
end
