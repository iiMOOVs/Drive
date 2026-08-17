--=================================================================
--  DRIVE Panel — Motorsport UI  (Borderless, Resizable)
--  Theme: Orange / Yellow / Black
--
--  FILE MAP (Ctrl+F the tag to jump)
--    [00] CONFIG .............. all tunable values in one place
--    [01] COLORS .............. theme palette
--    [02] DRAW HELPERS ........ dwBox / bigButton / segToggle / ...
--    [03] KEYBINDS ............ key list + storage + key picker
--    [04] CORE ................ ghost, cooldown, isTyping, placeCar
--    [10] FEATURE: TELEPORT
--    [11] FEATURE: MAP
--    [12] FEATURE: SKINS
--    [13] FEATURE: GRIP
--    [14] FEATURE: BOOST
--    [15] FEATURE: EXTRAS
--    [16] FEATURE: REWIND
--    [17] FEATURE: WEATHER
--    [18] FEATURE: SHADDA POINTS (player-saved spawn letters)
--    [20] NAV ICONS ........... one function per icon
--    [21] TAB REGISTRY ........ add / remove / reorder tabs here
--    [22] PANEL SHELL ......... logo, nav column, header, dispatch
--    [23] REGISTER APP
--    [24] UPDATE LOOP ......... calls each feature's update()
--    [25] SCREEN HUD .......... open hint + ghost + rewind overlays
--    [26] DRIVE CHAT .......... HTML chat (browser + Discord bridge)
--    [27] ONLINE EXTRAS ....... optional toolbar buttons
--    [28] MENU HOST ........... always-on menu (works without extras)
--    [29] DRIVE TAGS .......... name tags above cars (name + rank badge)
--
--  RULE: every feature block owns its own state, logic and UI.
--  To change one feature, edit only its block.
--=================================================================

math.randomseed(os.time())

--=================================================================
-- [00] CONFIG
--=================================================================
local CFG = {
  -- شعارك: رابط PNG أو مسار ملف. فاضي = كلمة DRIVE.
  LOGO_URL        = "https://i.imgur.com/WOV2nwa.png",
  -- الخط (بدائل مضمونة: "Tahoma;Weight=Bold" / "Arial;Weight=Bold")
  FONT            = "Segoe UI;Weight=Bold",

  PANEL_W         = 600,
  PANEL_H         = 640,
  PANEL_MIN_W     = 440,
  PANEL_MIN_H     = 420,
  NAV_W           = 140,

  MENU_TOGGLE_KEY = 68,    -- D = فتح/غلق القائمة  (لرجوعها للباك سلاش: 220)
  MENU_KEY_LABEL  = "D",   -- الاسم المعروض في الواجهة والتنبيه
  SHOW_OPEN_HINT  = true,  -- شعار "اضغط D لفتح القائمة" فوق الشاشة
  START_CLOSED    = true,  -- ندخل السيرفر والقائمة مقفولة = التنبيه يبان من أول لحظة
  HINT_INTRO_SEC  = 15,    -- أول كم ثانية بعد الدخول يكون التنبيه أكبر وأوضح

  TP_COOLDOWN     = 3,     -- ثواني بين كل انتقال
  GHOST_TIME      = 10,    -- ثواني الحماية بعد الانتقال

  BOOST_TARGET    = 235,   -- كم/س — افتراضي أول مرة فقط (بعدها من تبويب البوست)

  REWIND_MAX_SEC  = 20.0,
  REWIND_INTERVAL = 0.016,
  REWIND_SPEED    = 2.0,
}

-- تفضيل المستخدم: إخفاء شعارَي "اضغط D/C" (يفيد مثلاً وقت البث) — زر تبديل بأعلى القائمة
local hintStor = ac.storage{ hide_hints = false }

local FONT = CFG.FONT

--=================================================================
-- [01] COLORS
--=================================================================
local CW  = rgbm.colors.white
local CDm = rgbm(0.66, 0.67, 0.70, 1)
local CC  = rgbm(1.00, 0.72, 0.20, 1)
local CY  = rgbm(1.00, 0.84, 0.20, 1)
local CR  = rgbm(0.93, 0.32, 0.20, 1)
local COR = rgbm(1.00, 0.45, 0.06, 1)
local CGR = rgbm(1.00, 0.78, 0.16, 1)
local CPU = rgbm(1.00, 0.60, 0.10, 1)
local ACC = COR
local DK  = rgbm(0.04, 0.03, 0.02, 1)
local BGD = rgbm(0.035, 0.035, 0.042, 0.985)

--=================================================================
-- [02] DRAW HELPERS  (كلها بخط FONT العريض)
--=================================================================
local function dwBox(t, s, x, y, w, h, c)
  ui.pushDWriteFont(FONT); ui.setCursor(vec2(x, y))
  ui.dwriteTextAligned(t, s, ui.Alignment.Center, ui.Alignment.Center, vec2(w, h), false, c or CW)
  ui.popDWriteFont()
end

local function dwRightBox(t, s, x, y, w, h, c)
  ui.pushDWriteFont(FONT); ui.setCursor(vec2(x, y))
  ui.dwriteTextAligned(t, s, ui.Alignment.End, ui.Alignment.Center, vec2(w, h), false, c or CW)
  ui.popDWriteFont()
end

local function dwLeftBox(t, s, x, y, w, h, c)
  ui.pushDWriteFont(FONT); ui.setCursor(vec2(x, y))
  ui.dwriteTextAligned(t, s, ui.Alignment.Start, ui.Alignment.Center, vec2(w, h), false, c or CW)
  ui.popDWriteFont()
end

local dwMono = dwBox

local function sectionTitle(title, eye, X, Y, W)
  dwLeftBox(eye, 11, X, Y + 6, 150, 14, ACC)
  dwRightBox(title, 19, X, Y, W, 24, CW)
  ui.drawRectFilled(vec2(X + W - 38, Y + 27), vec2(X + W, Y + 30), ACC, 2)
end

local function glowRect(x, y, x2, y2, col, rad)
  for s = 4, 1, -1 do
    ui.drawRectFilled(vec2(x - s * 3, y - s * 3), vec2(x2 + s * 3, y2 + s * 3),
      rgbm(col.r, col.g, col.b, 0.055 / s), rad + s * 2)
  end
end

local function bigButton(x, y, w, h, label, col, id)
  ui.setCursor(vec2(x, y))
  local cl = ui.invisibleButton(id or ("##b" .. label), vec2(w, h))
  local hov = ui.itemHovered()
  local c = hov and rgbm(col.r * 1.14, col.g * 1.14, col.b * 1.14, 1) or col
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), c, 10)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h * 0.5), rgbm(1, 1, 1, 0.10), 10)
  if hov then ui.drawRect(vec2(x, y), vec2(x + w, y + h), rgbm(1, 1, 1, 0.35), 10, nil, 1) end
  dwBox(label, 16, x, y, w, h, DK)
  return cl
end

local function segToggle(x, y, w, h, opts, sel)
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + h), rgbm(1, 1, 1, 0.05), 10)
  ui.drawRect(vec2(x, y), vec2(x + w, y + h), rgbm(1, 1, 1, 0.08), 10, nil, 1)
  local n = #opts
  local iw = w / n
  local res = sel
  for i = 1, n do
    local ix = x + (i - 1) * iw
    ui.setCursor(vec2(ix, y))
    local cl = ui.invisibleButton("##sg" .. i .. opts[i], vec2(iw, h))
    if sel == i then
      ui.drawRectFilled(vec2(ix + 3, y + 3), vec2(ix + iw - 3, y + h - 3), rgbm(ACC.r, ACC.g, ACC.b, 0.9), 8)
    end
    dwBox(opts[i], 14, ix, y, iw, h, sel == i and DK or CDm)
    if cl then res = i end
  end
  return res
end

-- منتقي مفتاح موحّد (يستخدمه البوست والريوايند)
local function keyPicker(x, y, w, label, code, onClick)
  ui.setCursor(vec2(x, y))
  local cl  = ui.invisibleButton("##key" .. label, vec2(w, 28))
  local hov = ui.itemHovered()
  ui.drawRectFilled(vec2(x, y), vec2(x + w, y + 28), hov and rgbm(1, 1, 1, 0.10) or rgbm(1, 1, 1, 0.05), 8)
  ui.drawRect(vec2(x, y), vec2(x + w, y + 28), rgbm(ACC.r, ACC.g, ACC.b, 0.25), 8, nil, 1)
  dwBox(label .. ": " .. code .. "  (اضغط للتغيير)", 13, x, y, w, 28, CY)
  if cl and onClick then onClick() end
end

--=================================================================
-- [03] KEYBINDS
--   كل المفاتيح هنا. تبي تضيف مفتاح جديد للقائمة؟ زده في KEY_OPTIONS.
--=================================================================
local KEY_OPTIONS = {
  { name = 'Caps Lock',  code = 20 }, { name = 'Left Shift', code = 16 },
  { name = 'Left Ctrl',  code = 17 }, { name = 'Left Alt',   code = 18 },
  { name = 'Space',      code = 32 }, { name = 'Tab',        code = 9  },
  { name = 'B',          code = 66 }, { name = 'V',          code = 86 },
  { name = 'N',          code = 78 }, { name = 'G',          code = 71 },
  { name = 'H',          code = 72 }, { name = 'T',          code = 84 },
  { name = 'X',          code = 88 }, { name = 'Z',          code = 90 },
  { name = 'Y',          code = 89 }, { name = 'C',          code = 67 },
}

-- مخزن واحد لكل المفاتيح (نفس أسماء الحقول القديمة = الإعدادات المحفوظة ما تضيع)
local keyStore = ac.storage{ boostKey = 20, rewindKey = 89 }

local function keyName(code)
  for _, o in ipairs(KEY_OPTIONS) do if o.code == code then return o.name end end
  return 'Key #' .. code
end

-- ينقل للمفتاح اللي بعده، ويتخطى المفتاح المحجوز (avoid)
local function nextKey(cur, avoid)
  local idx = 1
  for i, o in ipairs(KEY_OPTIONS) do if o.code == cur then idx = i break end end
  idx = idx % #KEY_OPTIONS + 1
  if avoid and KEY_OPTIONS[idx].code == avoid then idx = idx % #KEY_OPTIONS + 1 end
  return KEY_OPTIONS[idx].code
end

--=================================================================
-- [04] CORE  (حماية الشبح + كولداون الانتقال + أدوات مشتركة)
--=================================================================
local Core = {
  ghostOn = false,
  ghostT  = 0,
  cd      = 0,   -- كولداون الانتقال
  clock   = 0,   -- يتقدّم كل فريم حتى لو النافذة مخفية
}

-- true لو اللاعب يكتب في الشات أو في خانة نص (نمنع المفاتيح وقتها)
local chatTyping = false   -- يصير true وقت الشات مفتوح — يوقف مفاتيح المنيو (رجوع/بوست/شدّات) عشان ما تكرش
local function isTyping()
  if chatTyping then return true end
  if type(ui.wantCaptureKeyboard) == "function" and ui.wantCaptureKeyboard() then return true end
  if type(ac.isChatOpen) == "function" and ac.isChatOpen() then return true end
  return false
end

-- تحقق إن المتجه صالح (مو NaN ولا لانهاية ولا قيم مجنونة) — يمنع كراش الفيزياء
local function vfinite(v)
  return v ~= nil and v.x == v.x and v.y == v.y and v.z == v.z
    and v.x < 1e9 and v.x > -1e9 and v.y < 1e9 and v.y > -1e9 and v.z < 1e9 and v.z > -1e9
end

function Core.ghostStart()
  Core.ghostT = CFG.GHOST_TIME
  Core.ghostOn = true
  pcall(function() ac.setCarGhost(0, true) end)
end

function Core.ghostEnd()
  Core.ghostOn = false
  Core.ghostT = 0
  pcall(function() ac.setCarGhost(0, false) end)
end

function Core.startCooldown() Core.cd = CFG.TP_COOLDOWN end
function Core.ready() return Core.cd <= 0 end

function Core.placeCarOnGround(x, z, fwd, el)
  el = el or 0.8
  local cH = 5000
  local d = physics.raycastTrack(vec3(x, cH, z), vec3(0, -1, 0), cH + 20)
  local f = vec3(fwd.x, 0, fwd.z)
  if f:length() < 1e-3 then f = vec3(0, 0, 1) else f = f:normalize() end
  if d ~= -1 then
    physics.setCarVelocity(0, vec3(0, 0, 0))
    physics.setCarPosition(0, vec3(x, cH - d + el, z), f)
  else
    physics.setCarVelocity(0, vec3(0, 0, 0))
    physics.setCarPosition(0, vec3(x, ac.getCar(0).position.y + 1, z), f)
  end
end

function Core.update(dt)
  Core.clock = Core.clock + dt
  if Core.cd > 0 then Core.cd = Core.cd - dt end
  if Core.ghostOn then
    Core.ghostT = Core.ghostT - dt
    if Core.ghostT <= 0 then Core.ghostEnd() end
  end
end

--=================================================================
-- [10] FEATURE: TELEPORT  (الانتقال إلى لاعب)
--=================================================================
local tpSel  = -1   -- index اللاعب المختار
local tpMode = 1    -- 1 = واقف ، 2 = بنفس السرعة

local function tpBehindStopped(car)
  local d = car.look
  physics.setCarVelocity(0, vec3(0, 0, 0))
  physics.setCarPosition(0, car.position + vec3(0, 0.1, 0) - d * 8, -d)
  Core.ghostStart()
end

local function tpBehindSameSpeed(car)
  local d = car.look
  physics.setCarPosition(0, car.position + vec3(0, 0.1, 0) - d * 8, -d)
  physics.setCarVelocity(0, car.velocity or vec3(0, 0, 0))
  Core.ghostStart()
end

local function drawTeleport(X, Y, W, H)
  sectionTitle("الانتقال إلى لاعب", "TELEPORT", X, Y, W)
  local btnH  = 40
  local btnY  = Y + H - btnH
  local togH  = 34
  local togY  = btnY - 12 - togH
  local listY = Y + 40
  local listH = (togY - 12) - listY

  ui.setCursor(vec2(X, listY))
  ui.drawRectFilled(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.028), 12)
  ui.drawRect(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.06), 12, nil, 1)
  ui.childWindow("##plist", vec2(W, listH), function()
    local ww = ui.windowWidth()
    local k = 0
    for i = 1, ac.getSim().carsCount - 1 do
      local c = ac.getCar(i)
      local n = ac.getDriverName(i)
      if c and c.isConnected and not c.isAIControlled and not string.find(n or "", "Traffic") then
        local ry = k * 46 + 4
        ui.setCursor(vec2(4, ry))
        local cl  = ui.invisibleButton("##pl" .. i, vec2(ww - 14, 42))
        local hov = ui.itemHovered()
        local sel = tpSel == i
        if sel then
          ui.drawRectFilled(vec2(4, ry), vec2(ww - 10, ry + 42), rgbm(ACC.r, ACC.g, ACC.b, 0.16), 8)
          ui.drawRectFilled(vec2(ww - 13, ry + 9), vec2(ww - 10, ry + 33), ACC, 2)
        elseif hov then
          ui.drawRectFilled(vec2(4, ry), vec2(ww - 10, ry + 42), rgbm(1, 1, 1, 0.05), 8)
        end
        ui.drawRectFilled(vec2(10, ry + 10), vec2(64, ry + 32), rgbm(0, 0, 0, 0.4), 6)
        dwMono(tostring(math.floor(c.speedKmh or 0)), 15, 10, ry + 10, 54, 22, CY)
        dwRightBox(n, 16, 70, ry, ww - 82, 42, sel and CW or rgbm(0.86, 0.87, 0.9, 1))
        if cl then tpSel = i end
        k = k + 1
      end
    end
    if k == 0 then dwBox("لا يوجد لاعبين متصلين", 15, 0, 16, ww, 22, CDm) end
    ui.dummy(vec2(1, k * 46 + 8))
  end)

  tpMode = segToggle(X, togY, W, togH, { "واقف", "بنفس السرعة" }, tpMode)

  local can = tpSel >= 1 and Core.ready()
  if can then glowRect(X, btnY, X + W, btnY + btnH, ACC, 10) end
  if bigButton(X, btnY, W, btnH, "انتقال", can and ACC or rgbm(0.24, 0.25, 0.30, 1), "##tpgo") and can then
    local c = ac.getCar(tpSel)
    if c and c.isConnected then
      if tpMode == 2 then tpBehindSameSpeed(c) else tpBehindStopped(c) end
      Core.startCooldown()
    end
  end
end


--=================================================================
-- [11] FEATURE: MAP  (خريطة الحلبة + انتقال بالدبل كليك)
--   منطق الانتقال نفس السكربت القديم الشغّال: شعاع لتحت من 2000م،
--   والانتقال يتم فقط لو الشعاع أصاب الأرض (raycast ~= -1).
--   لو ما أصاب (فراغ/حافة) ما يصير انتقال — فما فيه نزول من السماء.
--=================================================================
local mapReady   = false
local mapImage   = nil
local mapIniVals = {}
local mapImgSize, mapOffset
local mapPad   = vec2(60, 60)
local mapOfs   = -mapPad * 0.5
local mapScale, mapCarScale, mapDrawSize
local mapFirst = true
local mapTri   = 8
local mp3, md3 = vec3(), vec3()
local mp2, md2, mdx2 = vec2(), vec2(), vec2()

-- تحميل الخريطة مرة وحدة عند تشغيل السكربت (محمي حتى لا يطيح السكربت لو الحلبة بلا map.ini)
if ac.getPatchVersionCode() >= 2000 then
  pcall(function()
    local trackDir = ac.getFolder(ac.FolderID.ContentTracks) .. '/' .. ac.getTrackFullID('/')
    mapImage = trackDir .. '/map.png'
    ui.decodeImage(mapImage)
    local ini = trackDir .. "/data/map.ini"
    for a, b in ac.INIConfig.load(ini):serialize():gmatch("([_%a]+)=([-%d.]+)") do
      mapIniVals[a] = tonumber(b)
    end
    mapImgSize = ui.imageSize(mapImage)
    if mapIniVals.SCALE_FACTOR and mapIniVals.X_OFFSET and mapIniVals.Z_OFFSET and mapImgSize then
      mapOffset = vec2(mapIniVals.X_OFFSET, mapIniVals.Z_OFFSET)
      mapReady = true
    end
  end)
end

local function drawMap(X, Y, W, H)
  sectionTitle("الخريطة", "MAP", X, Y, W)
  dwRightBox("دبل كليك للانتقال · بكرة للتكبير", 12, X, Y + 26, W - 44, 14, CDm)
  local mY = Y + 44
  local mH = H - 44
  ui.setCursor(vec2(X, mY))
  ui.childWindow("##mapc", vec2(W, mH), function()
    if ac.getPatchVersionCode() < 2000 then
      dwBox("CSP 2000+", 15, 0, 10, ui.windowWidth(), 22, CR); return
    end
    if not mapReady then
      dwBox("لا توجد خريطة لهذه الحلبة", 15, 0, 10, ui.windowWidth(), 22, CR); return
    end

    if mapFirst then
      mapScale = math.min((ui.windowWidth() - mapPad.x) / mapImgSize.x,
                          (ui.windowHeight() - mapPad.y) / mapImgSize.y)
      mapCarScale = mapScale / mapIniVals.SCALE_FACTOR
      mapDrawSize = mapImgSize * mapScale
      if ui.isImageReady(mapImage) then mapFirst = false end
    end

    ui.drawImage(mapImage, -mapOfs, -mapOfs + mapDrawSize)

    -- زوم بالبكرة
    if ui.windowHovered() and ac.getUI().mouseWheel ~= 0 then
      local w = ac.getUI().mouseWheel
      if (w < 0 and mapDrawSize.x + mapPad.x > ui.windowWidth() and mapDrawSize.y + mapPad.y > ui.windowHeight()) or w > 0 then
        local old = mapDrawSize
        mapScale = mapScale * (1 + w * 0.15)
        mapDrawSize = mapImgSize * mapScale
        mapCarScale = mapScale / mapIniVals.SCALE_FACTOR
        mapOfs = mapOfs + (mapDrawSize - old) * (mapOfs + ui.mouseLocalPos()) / old
      else
        mapOfs = -mapPad * 0.5
        mapScale = math.min((ui.windowWidth() - mapPad.x) / mapImgSize.x,
                            (ui.windowHeight() - mapPad.y) / mapImgSize.y)
        mapDrawSize = mapImgSize * mapScale
        mapCarScale = mapScale / mapIniVals.SCALE_FACTOR
      end
    end

    -- بقية اللاعبين
    for i = ac.getSim().carsCount - 1, 1, -1 do
      local c = ac.getCar(i)
      if c and c.isConnected and not c.isHidingLabels then
        mp2:set(c.position.x, c.position.z):add(mapOffset):scale(mapCarScale):add(-mapOfs)
        md2:set(c.look.x, c.look.z); mdx2:set(c.look.z, -c.look.x)
        ui.drawTriangleFilled(mp2 + md2 * mapTri,
                              mp2 - md2 * mapTri - mdx2 * mapTri * 0.75,
                              mp2 - md2 * mapTri + mdx2 * mapTri * 0.75, rgbm(0.95, 0.25, 0.15, 1))
      end
    end

    -- سيارتك
    mp3 = ac.getCameraPosition()
    mp2:set(mp3.x, mp3.z):add(mapOffset):scale(mapCarScale):add(-mapOfs)
    md3 = ac.getCameraForward()
    md2 = vec2(md3.x, md3.z):normalize()
    mdx2:set(md3.z, -md3.x):normalize()
    local sc = Core.ghostOn and rgbm(1.00, 0.84, 0.20, 1) or rgbm(1.00, 0.45, 0.06, 1)
    ui.drawTriangleFilled(mp2 + md2 * mapTri,
                          mp2 - md2 * mapTri - mdx2 * mapTri * 0.75,
                          mp2 - md2 * mapTri + mdx2 * mapTri * 0.75, sc)

    -- دبل كليك = انتقال  (نفس منطق السكربت القديم بالضبط)
    if ui.mouseDoubleClicked(ui.MouseButton.Left) and ui.windowHovered() and Core.ready() then
      local cp = (ui.mouseLocalPos() + mapOfs) / mapCarScale - mapOffset
      local raycast = physics.raycastTrack(vec3(cp.x, 2000, cp.y), vec3(0, -1, 0), 3000)
      if raycast ~= -1 then
        physics.setCarVelocity(0, vec3(0, 0, 0))
        physics.setCarPosition(0, vec3(cp.x, 2000 - raycast + 0.5, cp.y), ac.getCameraForward())
        Core.ghostStart()
        Core.startCooldown()
      else
        ui.toast(ui.Icons.Warning, "DRIVE: No road here — try another spot")
      end
    end

    -- سحب الخريطة
    ui.invisibleButton('###md', ui.windowSize())
    if ui.mouseDown() and ui.itemHovered() then mapOfs = mapOfs - ui.mouseDelta() end
  end)
end
 
--=================================================================
-- [12] FEATURE: SKINS  (تطبيق بالاسم + مزامنة أونلاين)
--   تنبيه: لا تغيّر شكل syncCarSkin — تغييره يكسر التوافق مع
--   اللاعبين اللي معهم النسخة القديمة من السكربت.
--=================================================================
local skinCarDir   = ac.getFolder(ac.FolderID.ContentCars) .. '/' .. ac.getCarID(0)
local skinList     = {}
local skinCurrent  = ac.getCarSkinID(0)
local skinOriginal = skinCurrent
local skinRemote   = {}

pcall(function()
  io.scanDir(skinCarDir .. '/skins', '*', function(fn)
    if io.dirExists(skinCarDir .. '/skins/' .. fn) then table.insert(skinList, { name = fn }) end
  end)
end)
table.sort(skinList, function(a, b) return a.name < b.name end)

local function skinSanitize(name)
  if type(name) ~= 'string' or name == '' then return nil end
  if name:find('[/\\]') or name:find('%.%.') then return nil end
  if not io.dirExists(skinCarDir .. '/skins/' .. name) then return nil end
  return name
end

local function skinApplyTextures(carNode, folder)
  local mapping = {}
  io.scanDir(folder, '*', function(fn)
    local l = fn:lower()
    if l == 'livery.png' or l == 'livery.jpg' or l == 'preview.jpg' or l == 'preview.png'
       or l == 'ui_skin.json' or l == 'cm_skin.json' then return end
    if l:match('%.dds$') or l:match('%.png$') or l:match('%.jpg$') or l:match('%.jpeg$') then
      mapping[fn] = folder .. '/' .. fn
    end
  end)
  if next(mapping) then carNode:applySkin(mapping) end
end

local function skinApply(skinName, carIndex)
  local carNode = ac.findNodes('carRoot:' .. carIndex)
  if not carNode or #carNode == 0 then return end

  -- امسح السكن الحالي كامل (يرجّع الألوان والانعكاسات الأصلية)
  carNode:resetSkin()

  if skinName ~= skinOriginal then
    -- 1) الطريقة الصحيحة: تطبيق بالاسم (يحمّل السكن كامل بألوانه)
    pcall(function() carNode:applySkin(skinName) end)
    -- 2) تعزيز/بديل: تبديل التكستشرات من مجلد السكن (لو الاسم ما كفى)
    skinApplyTextures(carNode, skinCarDir .. '/skins/' .. skinName)
  end

  ac.refreshCarColor(carIndex)
end

local syncCarSkin = ac.OnlineEvent({
  msgType = ac.StructItem.byte(),
  skin    = ac.StructItem.string(120),
}, function(sender, data)
  if not sender or sender.index == 0 then return end
  if data.msgType == 1 then
    if skinCurrent ~= skinOriginal then
      setTimeout(function() syncCarSkin({ msgType = 0, skin = skinCurrent }) end, math.random() * 1.5)
    end
    return
  end
  local skin = skinSanitize(data.skin)
  if not skin then return end
  if skinRemote[sender.index] == skin then return end
  skinRemote[sender.index] = skin
  skinApply(skin, sender.index)
end)

local function skinAnnounce(skin)
  syncCarSkin({ msgType = 0, skin = skin })
  setTimeout(function() if skinCurrent == skin then syncCarSkin({ msgType = 0, skin = skin }) end end, 1.5)
end

local function skinChange(newSkin)
  if not newSkin or newSkin == skinCurrent then return end
  skinApply(newSkin, 0)
  skinCurrent = newSkin
  skinAnnounce(newSkin)
end

local skinReqSent = 0
local function skinRequestAll()
  if skinReqSent >= 2 then return end
  skinReqSent = skinReqSent + 1
  syncCarSkin({ msgType = 1, skin = '' })
  setTimeout(skinRequestAll, 6.0)
end
setTimeout(skinRequestAll, 3.0)

local function drawSkin(X, Y, W, H)
  sectionTitle("سكنات السيارة", "LIVERY", X, Y, W)
  local byH   = 38
  local byY   = Y + H - byH
  local gridY = Y + 40
  local gridH = (byY - 10) - gridY
  ui.setCursor(vec2(X, gridY))
  ui.childWindow("##skg", vec2(W, gridH), function()
    local ww = ui.windowWidth()
    if #skinList == 0 then dwBox("لا توجد سكنات", 15, 0, 16, ww, 22, CY); return end
    local cols = 2
    local cw = (ww - 8 - (cols - 1) * 6) / cols
    local ch = cw * 0.5
    for i, skin in ipairs(skinList) do
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      local cx  = 3 + col * (cw + 6)
      local cyy = row * (ch + 22)
      local sel = skinCurrent == skin.name
      ui.setCursor(vec2(cx, cyy))
      local cl  = ui.invisibleButton("##sk" .. i, vec2(cw, ch + 18))
      local hov = ui.itemHovered()
      local pp  = skinCarDir .. '/skins/' .. skin.name .. '/preview.jpg'
      if ui.isImageReady(pp) then
        ui.setCursor(vec2(cx, cyy)); ui.image(pp, vec2(cw, ch))
      else
        ui.decodeImage(pp)
        ui.drawRectFilled(vec2(cx, cyy), vec2(cx + cw, cyy + ch), rgbm(1, 1, 1, 0.05), 8)
        dwBox("...", 13, cx, cyy, cw, ch, CDm)
      end
      ui.drawRectFilled(vec2(cx, cyy), vec2(cx + cw, cyy + ch * 0.35), rgbm(1, 1, 1, 0.10), 8)
      if sel then ui.drawRect(vec2(cx, cyy), vec2(cx + cw, cyy + ch), ACC, 8, nil, 3)
      elseif hov then ui.drawRect(vec2(cx, cyy), vec2(cx + cw, cyy + ch), rgbm(1, 1, 1, 0.4), 8, nil, 1.5)
      else ui.drawRect(vec2(cx, cyy), vec2(cx + cw, cyy + ch), rgbm(1, 1, 1, 0.12), 8, nil, 1) end
      dwBox(skin.name, 11, cx, cyy + ch + 2, cw, 15, sel and ACC or CDm)
      if cl then skinChange(skin.name) end
    end
    ui.dummy(vec2(1, math.ceil(#skinList / 2) * (ch + 22) + 4))
  end)

  local bw = (W - 8) / 2
  if bigButton(X, byY, bw, byH, "الأصلي", rgbm(0.24, 0.25, 0.30, 1), "##skdef") then
    skinChange(skinOriginal)
  end
  if bigButton(X + bw + 8, byY, bw, byH, "عشوائي", ACC, "##skrnd") then
    if #skinList > 0 then
      local r = skinList[math.random(#skinList)]
      if r then skinChange(r.name) end
    end
  end
end

--=================================================================
-- [13] FEATURE: GRIP  (التماسك: gripVal ∈ [-1,1] يمين خشن / يسار ناعم)
--=================================================================
local gripVal = 0.0

local function gripApply()
  pcall(function() physics.setGripDecrease(0, ac.Wheel.All, -gripVal * 0.7) end)
end

local function drawGrip(X, Y, W, H)
  local stackH = 34 + 64 + 40 + 48 + 40
  local sy = Y + math.max(0, (H - stackH) * 0.5)
  sectionTitle("التماسك", "TRACTION", X, sy, W); sy = sy + 50

  local lbl, lc = "عادي", CDm
  if gripVal > 0.02 then lbl, lc = "خشن / تماسك", CGR
  elseif gripVal < -0.02 then lbl, lc = "ناعم / زلق", COR end
  dwMono(string.format("%+.2f", gripVal), 52, X, sy, W, 52, lc); sy = sy + 54
  dwBox(lbl, 15, X, sy, W, 18, lc); sy = sy + 28

  dwLeftBox("ناعم ←", 13, X, sy - 2, 80, 18, CDm)
  dwRightBox("→ خشن", 13, X + W - 80, sy - 2, 80, 18, CDm)
  ui.setCursor(vec2(X, sy)); ui.setNextItemWidth(W)
  local nv, changed = ui.slider("##grp", gripVal, -1.0, 1.0, "")
  if changed then gripVal = math.clamp(nv, -1, 1); gripApply() end
  ui.drawRectFilled(vec2(X + W * 0.5 - 1, sy - 3), vec2(X + W * 0.5 + 1, sy + 22), rgbm(1, 1, 1, 0.3), 1)
  sy = sy + 46

  local presets = { { "زلق", -1.0 }, { "عادي", 0.0 }, { "خشن", 1.0 } }
  local bw = (W - 16) / 3
  for i = 1, 3 do
    local bx = X + (i - 1) * (bw + 8)
    ui.setCursor(vec2(bx, sy))
    local cl = ui.invisibleButton("##gp" .. i, vec2(bw, 38))
    local on = math.abs(gripVal - presets[i][2]) < 0.001
    ui.drawRectFilled(vec2(bx, sy), vec2(bx + bw, sy + 38),
      on and rgbm(ACC.r, ACC.g, ACC.b, 0.85) or rgbm(1, 1, 1, 0.05), 10)
    dwBox(presets[i][1], 15, bx, sy, bw, 38, on and DK or CW)
    if cl then gripVal = presets[i][2]; gripApply() end
  end
end

--=================================================================
-- [14] FEATURE: BOOST  (toggle · anti-fly · adjustable speed/smoothing)
--   Press once = ON, press again = OFF. Braking cancels it.
--   Target speed slider 185-320. Instant or Gradual acceleration.
--   Only the settings UI was restyled to match the panel — the
--   behavior is identical to the tuned version.
--=================================================================
local BOOST_MIN_KMH = 5

-- persisted so settings survive a rejoin
local boostStore = ac.storage{
  mode        = 1,      -- 1 = Instant , 2 = Gradual
  accelPower  = 15.0,   -- smoothing (Gradual only)
  cooldown    = 5.0,    -- seconds
  targetSpeed = 230.0,  -- km/h
}

local boostCd       = 0
local boostPrevKey  = false
local boostPulse    = 0
local boostBtnLatch = false
local isBoostActive = false

local function getFlatDirection(car)
  local f = vec3(car.look.x, 0, car.look.z)
  if f:length() < 1e-3 then return vec3(0, 0, 1) end
  return f:normalize()
end

local function stopBoost()
  if not isBoostActive then return end
  isBoostActive = false
  boostCd = boostStore.cooldown
  ui.toast(ui.Icons.Warning, "DT Drive: Boost Deactivated - Cooldown Started")
end

local function startBoost()
  local car = ac.getCar(0)
  if not car then return false end
  if car.speedKmh < BOOST_MIN_KMH then
    ui.toast(ui.Icons.Warning, "DT Drive: Speed must be over 5 km/h!")
    return false
  end
  isBoostActive = true
  Core.ghostStart()
  ui.toast(ui.Icons.Confirm, "DT Drive: Boost Activated!")
  return true
end

local function toggleBoost()
  if isBoostActive then stopBoost()
  elseif boostCd <= 0 then startBoost() end
end

local function boostUpdate(dt)
  boostPulse = boostPulse + dt
  local car = ac.getCar(0)

  if boostCd > 0 and not isBoostActive then boostCd = boostCd - dt end

  if isBoostActive and car then
    if car.brake > 0.05 then
      stopBoost()
    else
      local target_ms = boostStore.targetSpeed / 3.6
      local flatLook  = getFlatDirection(car)
      local currentVel = car.velocity
      local targetVel  = flatLook * target_ms
      targetVel.y = currentVel.y
      if boostStore.mode == 1 then
        physics.setCarVelocity(0, targetVel)
      else
        local newVel = math.lerp(currentVel, targetVel, math.min(1, dt * boostStore.accelPower))
        newVel.y = currentVel.y
        physics.setCarVelocity(0, newVel)
      end
    end
  end

  local down = (not isTyping()) and ui.keyboardButtonDown(keyStore.boostKey)
  if down and not boostPrevKey then toggleBoost() end
  boostPrevKey = down
end

-- panel-styled labelled slider (same look as the rest of the panel)
local function boostSlider(label, x, y, w, id, val, mn, mx, fmt)
  dwLeftBox(label, 13, x, y, 260, 16, ACC)
  ui.setCursor(vec2(x, y + 18))
  ui.setNextItemWidth(w)
  ui.pushStyleColor(ui.StyleColor.SliderGrab, ACC)
  ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(1, 1, 1, 0.05))
  local nv = ui.slider(id, val, mn, mx, fmt)
  ui.popStyleColor(2)
  return nv
end

local function drawBoost(X, Y, W, H)
  local car = ac.getCar(0)
  local spd = car and math.floor(car.speedKmh) or 0

  sectionTitle("BOOST", "BOOST", X, Y, W)

  -- ===== speed card =====
  local cardH = 84
  local sy    = Y + 46
  ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + cardH), rgbm(1, 1, 1, 0.05), 14)
  ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + cardH * 0.5), rgbm(1, 1, 1, 0.03), 14)
  ui.drawRect(vec2(X, sy), vec2(X + W, sy + cardH), rgbm(ACC.r, ACC.g, ACC.b, 0.28), 14, nil, 1)
  dwBox("Current Speed", 12, X, sy + 8, W, 14, CDm)
  dwMono(tostring(spd), 42, X, sy + 22, W, 42, CC)
  dwBox(string.format("km/h   ·   Target %d", math.floor(boostStore.targetSpeed)), 11, X, sy + 62, W, 12, CDm)
  local pct = math.min(spd / math.max(boostStore.targetSpeed, 1), 1)
  local by  = sy + cardH - 9
  ui.drawRectFilled(vec2(X + 16, by), vec2(X + W - 16, by + 3), rgbm(0, 0, 0, 0.45), 2)
  if pct > 0 then
    ui.drawRectFilled(vec2(X + 16, by), vec2(X + 16 + (W - 32) * pct, by + 3), pct >= 1 and CGR or COR, 2)
  end

  -- ===== square button =====
  local BS  = 118
  local bx  = X + (W - BS) * 0.5
  local byy = sy + cardH + 16
  ui.setCursor(vec2(bx, byy))
  local cl  = ui.invisibleButton("##bst", vec2(BS, BS))
  local act = ui.itemActive()
  local hov = ui.itemHovered()

  local clicked = false
  if (cl or act) and not boostBtnLatch then
    boostBtnLatch = true
    clicked = true
  elseif not act and not cl then
    boostBtnLatch = false
  end

  if isBoostActive then
    glowRect(bx, byy, bx + BS, byy + BS, CGR, 18)
    local pulse = 0.90 + 0.10 * math.sin(boostPulse * 10)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(CGR.r * pulse, CGR.g * pulse, CGR.b * pulse, 1), 18)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.6), 18, nil, 2)
    dwBox("ACTIVE", 24, bx, byy + BS * 0.5 - 16, BS, 32, CW)
    if clicked then stopBoost() end

  elseif boostCd > 0 then
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.06), 18)
    local pr = 1 - boostCd / math.max(boostStore.cooldown, 0.01)
    ui.drawRectFilled(vec2(bx, byy + BS * (1 - pr)), vec2(bx + BS, byy + BS), rgbm(CPU.r, CPU.g, CPU.b, 0.22), 18)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.14), 18, nil, 1)
    dwMono(string.format("%.1f", boostCd), 34, bx, byy + BS * 0.5 - 26, BS, 38, CW)
    dwBox("SEC", 12, bx, byy + BS * 0.5 + 14, BS, 16, CDm)

  else
    glowRect(bx, byy, bx + BS, byy + BS, COR, 18)
    local pulse = 0.90 + 0.10 * math.sin(boostPulse * 4)
    local col = hov and rgbm(1, 0.58, 0.20, 1) or rgbm(COR.r * pulse + 0.05, COR.g * pulse, COR.b * pulse, 1)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), col, 18)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS * 0.5), rgbm(1, 1, 1, 0.16), 18)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.32), 18, nil, 2)
    local ln = 12
    for _, cc in ipairs({ { bx + 10, byy + 10, 1, 1 }, { bx + BS - 10, byy + 10, -1, 1 },
                          { bx + 10, byy + BS - 10, 1, -1 }, { bx + BS - 10, byy + BS - 10, -1, -1 } }) do
      ui.drawLine(vec2(cc[1], cc[2]), vec2(cc[1] + ln * cc[3], cc[2]), rgbm(0, 0, 0, 0.5), 2)
      ui.drawLine(vec2(cc[1], cc[2]), vec2(cc[1], cc[2] + ln * cc[4]), rgbm(0, 0, 0, 0.5), 2)
    end
    dwBox("BOOST", 24, bx, byy + BS * 0.5 - 16, BS, 32, DK)
    if clicked then startBoost() end
  end

  -- status line
  if spd < BOOST_MIN_KMH and boostCd <= 0 and not isBoostActive then
    dwBox("Speed must be over 5 km/h", 13, X, byy + BS + 8, W, 18, CR)
  else
    local statusText = isBoostActive and "Brake to stop"
      or string.format("Ready  ·  %d km/h", math.floor(boostStore.targetSpeed))
    dwBox(statusText, 13, X, byy + BS + 8, W, 18, CC)
  end

  -- ===== settings panel (scrolls if window is short) =====
  local gy   = byy + BS + 30
  local setH = math.max((Y + H - 38) - gy, 70)
  ui.setCursor(vec2(X, gy))
  ui.drawRectFilled(vec2(X, gy), vec2(X + W, gy + setH), rgbm(1, 1, 1, 0.028), 12)
  ui.drawRect(vec2(X, gy), vec2(X + W, gy + setH), rgbm(1, 1, 1, 0.06), 12, nil, 1)
  ui.childWindow("##bset", vec2(W, setH), function()
    local ww = ui.windowWidth() - 20
    local ly = 8

    -- acceleration mode
    dwLeftBox("Acceleration", 13, 10, ly, 200, 16, ACC)
    ly = ly + 20
    local ns = segToggle(10, ly, ww, 32, { "Instant", "Gradual" }, boostStore.mode)
    if ns ~= boostStore.mode then boostStore.mode = ns end
    ly = ly + 44

    -- target speed
    local nv = boostSlider("Target Speed", 10, ly, ww, "##btgt",
      boostStore.targetSpeed, 185, 320, "  %.0f km/h")
    if math.abs(nv - boostStore.targetSpeed) > 0.01 then boostStore.targetSpeed = nv end
    ly = ly + 48

    -- smoothing (Gradual only)
    if boostStore.mode == 2 then
      nv = boostSlider("Smoothing  (higher = snappier)", 10, ly, ww, "##baccel",
        boostStore.accelPower, 1, 50, "  %.0f")
      if math.abs(nv - boostStore.accelPower) > 0.01 then boostStore.accelPower = nv end
      ly = ly + 48
    end

    -- cooldown
    nv = boostSlider("Cooldown", 10, ly, ww, "##bcd",
      boostStore.cooldown, 1, 120, "  %.0f s")
    if math.abs(nv - boostStore.cooldown) > 0.01 then boostStore.cooldown = nv end
    ly = ly + 48

    -- reset
    if bigButton(10, ly, ww, 32, "Reset to defaults", rgbm(0.30, 0.31, 0.36, 1), "##brst") then
      boostStore.mode        = 1
      boostStore.accelPower  = 15.0
      boostStore.cooldown    = 5.0
      boostStore.targetSpeed = 230.0
    end
    ly = ly + 40

    dwBox("Press to toggle · brake to cancel", 12, 10, ly, ww, 16, CDm)
    ui.dummy(vec2(1, ly + 24))
  end)

  -- ===== key =====
  keyPicker(X, Y + H - 30, W, "Boost Key", keyName(keyStore.boostKey), function()
    keyStore.boostKey = nextKey(keyStore.boostKey, keyStore.rewindKey)
    boostPrevKey = false
  end)
end

--=================================================================
-- [15] FEATURE: EXTRAS  (الأكسترا + زر الفلاشر HAZARDS الثابت)
--   الفلاشر: نثبّته بإعادة تفعيله كل ما ينطفئ — نفس مبدأ قفل الأكسترا.
--   يستخدم ac.setTurningLights مع TurningLights.Hazards.
--=================================================================
local extraKeys   = { "extraA","extraB","extraC","extraD","extraE","extraF","extraG","extraH","extraI" }
local extraLocked = {}
local extraAvail  = {}
local extraInit   = false
for i = 1, #extraKeys do extraLocked[i] = false end

local hazardsLocked = false   -- الفلاشر مثبّت؟

local function extrasUpdate()
  local car = ac.getCar(0)
  if not car then return end

  -- تثبيت الفلاشر: لو مقفول ومو مفعّل، نرجّع نفعّله
  if hazardsLocked then
    local on = false
    -- بعض إصدارات CSP تعرض حالة الفلاشر بأسماء مختلفة — نتحقق بأمان
    if car.hazardLights ~= nil then on = car.hazardLights
    elseif car.turningLights ~= nil then on = (car.turningLights == ac.TurningLights.Hazards) end
    if not on then
      pcall(function() ac.setTurningLights(ac.TurningLights.Hazards) end)
    end
  end

  if not extraInit then
    for i, key in ipairs(extraKeys) do extraAvail[i] = (car[key] ~= nil) end
    extraInit = true
    return
  end
  for i, key in ipairs(extraKeys) do
    if extraAvail[i] and extraLocked[i] and car[key] == false then
      pcall(function() ac.setExtraSwitch(i - 1, true) end)
    end
  end
end

local function drawExtras(X, Y, W, H)
  sectionTitle("الأكسترا", "EXTRAS", X, Y, W)

  -- ===== زر الفلاشر HAZARDS الثابت (فوق) =====
  local hy, hh = Y + 40, 48
  ui.drawRectFilled(vec2(X, hy), vec2(X + W, hy + hh),
    hazardsLocked and rgbm(ACC.r, ACC.g, ACC.b, 0.16) or rgbm(1, 1, 1, 0.03), 12)
  ui.drawRect(vec2(X, hy), vec2(X + W, hy + hh), rgbm(ACC.r, ACC.g, ACC.b, 0.25), 12, nil, 1)
  -- اسم موسّط بين الزر واليمين
  dwBox("HAZARDS  ·  الفلشر", 16, 100, hy, W - 114, hh, hazardsLocked and CW or CDm)
  -- زر التبديل (يسار)
  local pw, ph, px, py = 76, 30, X + 14, hy + (hh - 30) * 0.5
  ui.setCursor(vec2(px, py))
  local hcl = ui.invisibleButton("##hazbtn", vec2(pw, ph))
  ui.drawRectFilled(vec2(px, py), vec2(px + pw, py + ph),
    hazardsLocked and ACC or rgbm(0.28, 0.29, 0.33, 1), 14)
  dwBox(hazardsLocked and "ON" or "OFF", 14, px, py, pw, ph, hazardsLocked and DK or CW)
  if hcl then
    hazardsLocked = not hazardsLocked
    pcall(function()
      ac.setTurningLights(hazardsLocked and ac.TurningLights.Hazards or ac.TurningLights.None)
    end)
  end

  -- ===== قائمة الأكسترا (تحت الفلاشر) =====
  local listY = hy + hh + 10
  local listH = (Y + H) - listY
  ui.setCursor(vec2(X, listY))
  ui.drawRectFilled(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.028), 12)
  ui.drawRect(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.06), 12, nil, 1)
  ui.childWindow("##exlist", vec2(W, listH), function()
    local ww = ui.windowWidth()
    local k = 0
    for i, key in ipairs(extraKeys) do
      if extraAvail[i] then
        local ry = k * 50 + 4
        local locked = extraLocked[i]
        ui.drawRectFilled(vec2(4, ry), vec2(ww - 10, ry + 44),
          locked and rgbm(ACC.r, ACC.g, ACC.b, 0.14) or rgbm(1, 1, 1, 0.03), 10)
        -- اسم الإضافة موسّط في المساحة بين الزر واليمين
        dwBox("EXTRA " .. string.upper(string.sub(key, 6)), 16, 100, ry, ww - 114, 44, locked and CW or CDm)
        -- زر التبديل (يسار)
        local bpw, bph, bpx, bpy = 76, 28, 14, ry + 8
        ui.setCursor(vec2(bpx, bpy))
        local cl = ui.invisibleButton("##ex" .. i, vec2(bpw, bph))
        ui.drawRectFilled(vec2(bpx, bpy), vec2(bpx + bpw, bpy + bph), locked and ACC or rgbm(0.28, 0.29, 0.33, 1), 14)
        dwBox(locked and "ON" or "OFF", 14, bpx, bpy, bpw, bph, locked and DK or CW)
        if cl then
          extraLocked[i] = not locked
          pcall(function() ac.setExtraSwitch(i - 1, extraLocked[i]) end)
        end
        k = k + 1
      end
    end
    if k == 0 then dwBox("لا توجد إضافات لهذه السيارة", 15, 0, 16, ww, 22, CDm) end
    ui.dummy(vec2(1, k * 50 + 8))
  end)
end

--=================================================================
-- [16] FEATURE: REWIND  (الرجوع بالزمن + تحكم كامل مثل البوست)
--   امسك المفتاح للرجوع. لوحة إعدادات مطابقة للبوست:
--     · سرعة الرجوع (كم أسرع من الزمن الحقيقي)
--     · مدة التسجيل (كم ثانية يحفظ للخلف)
--     · المفتاح من المنتقي
--   القيم محفوظة في ac.storage — تبقى بعد الخروج.
--   ملاحظة: مدة التسجيل تُطبّق فوراً؛ لو صغّرتها ينقص المخزون،
--   ولو كبّرتها يبدأ يمتلئ للحد الجديد.
--=================================================================
local rewindStore = ac.storage{
  maxSec   = CFG.REWIND_MAX_SEC * 1.0,   -- مدة التسجيل بالثواني
  speed    = CFG.REWIND_SPEED * 1.0,     -- مضاعف سرعة الرجوع
}

-- أزرار جاهزة لسرعة الرجوع
local REWIND_SPEED_PRESETS = { { "بطيء", 1.0 }, { "عادي", 2.0 }, { "سريع", 4.0 }, { "فوري", 8.0 } }

local rHistory      = {}
local rRecordTimer  = 0
local rIsRewinding  = false
local rWasRewinding = false
local rLastState    = nil

local function rewindMaxFrames()
  return math.floor(rewindStore.maxSec / CFG.REWIND_INTERVAL)
end

local function rewindUpdate(dt)
  local car = ac.getCar(0)
  if not car then return end

  local down = (not isTyping()) and ui.keyboardButtonDown(keyStore.rewindKey)

  if down and #rHistory > 0 then
    rIsRewinding = true; rWasRewinding = true
    local popN = math.floor((dt * rewindStore.speed) / CFG.REWIND_INTERVAL)
    if popN < 1 then popN = 1 end
    for _ = 1, popN do if #rHistory > 0 then rLastState = table.remove(rHistory) end end
    -- تحصين: لا نطعم الفيزياء إحداثيات/اتجاه غير صالح (يمنع كراش ReplayManager)
    if rLastState and vfinite(rLastState.pos) and vfinite(rLastState.look) and vfinite(rLastState.up)
       and rLastState.look:length() > 0.05 and rLastState.up:length() > 0.05 then
      pcall(function()
        physics.setCarVelocity(0, vec3(0, 0, 0))
        physics.setCarPosition(0, rLastState.pos, -rLastState.look, rLastState.up)
      end)
    end
  else
    rIsRewinding = false
    if rWasRewinding then
      rWasRewinding = false
      if rLastState and vfinite(rLastState.vel) then pcall(function() physics.setCarVelocity(0, rLastState.vel) end) end
      Core.ghostStart()
    end
    rRecordTimer = rRecordTimer + dt
    if rRecordTimer >= CFG.REWIND_INTERVAL then
      rRecordTimer = rRecordTimer % CFG.REWIND_INTERVAL
      table.insert(rHistory, {
        pos  = vec3(car.position.x, car.position.y, car.position.z),
        look = vec3(car.look.x, car.look.y, car.look.z),
        up   = vec3(car.up.x, car.up.y, car.up.z),
        vel  = vec3(car.velocity.x, car.velocity.y, car.velocity.z),
      })
      -- نقص الزائد فوراً لو صغّر اللاعب مدة التسجيل
      while #rHistory > rewindMaxFrames() do table.remove(rHistory, 1) end
    end
  end
end

-- سلايدر بعنوان (نفس ستايل البوست)
local function rewindSlider(label, x, y, w, id, val, mn, mx, fmt)
  dwLeftBox(label, 13, x, y, 260, 16, ACC)
  ui.setCursor(vec2(x, y + 18))
  ui.setNextItemWidth(w)
  ui.pushStyleColor(ui.StyleColor.SliderGrab, ACC)
  ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(1, 1, 1, 0.05))
  local nv = ui.slider(id, val, mn, mx, fmt)
  ui.popStyleColor(2)
  return nv
end

local function drawRewind(X, Y, W, H)
  local histSec = #rHistory * CFG.REWIND_INTERVAL
  local ready   = histSec > 2.0
  sectionTitle("الرجوع بالزمن", "REWIND", X, Y, W)

  -- ===== بطاقة الذاكرة =====
  local cardH = 84
  local sy    = Y + 46
  ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + cardH), rgbm(1, 1, 1, 0.05), 14)
  ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + cardH * 0.5), rgbm(1, 1, 1, 0.03), 14)
  ui.drawRect(vec2(X, sy), vec2(X + W, sy + cardH), rgbm(ACC.r, ACC.g, ACC.b, 0.28), 14, nil, 1)
  dwBox("الذاكرة المسجّلة", 12, X, sy + 8, W, 14, CDm)
  dwMono(string.format("%.1f / %.0f", histSec, rewindStore.maxSec), 40, X, sy + 22, W, 42, ready and CGR or CC)
  dwBox("ثانية", 11, X, sy + 62, W, 12, CDm)
  local pct = math.min(histSec / math.max(rewindStore.maxSec, 1), 1)
  local by  = sy + cardH - 9
  ui.drawRectFilled(vec2(X + 16, by), vec2(X + W - 16, by + 3), rgbm(0, 0, 0, 0.45), 2)
  if pct > 0 then ui.drawRectFilled(vec2(X + 16, by), vec2(X + 16 + (W - 32) * pct, by + 3), ACC, 2) end

  -- ===== الزر المربّع (مؤشر — الفعل بمسك المفتاح) =====
  local BS  = 118
  local bx  = X + (W - BS) * 0.5
  local byy = sy + cardH + 16
  if rIsRewinding then
    glowRect(bx, byy, bx + BS, byy + BS, COR, 18)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 0.5, 0.12, 1), 18)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS * 0.5), rgbm(1, 1, 1, 0.16), 18)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.32), 18, nil, 2)
    dwBox("REWIND", 24, bx, byy + BS * 0.5 - 24, BS, 32, DK)
    dwBox("جارٍ الرجوع...", 13, bx, byy + BS * 0.5 + 12, BS, 18, DK)
  else
    local base = ready and rgbm(0.16, 0.5, 0.2, 1) or rgbm(0.22, 0.23, 0.27, 1)
    if ready then glowRect(bx, byy, bx + BS, byy + BS, CGR, 18) end
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS), base, 18)
    ui.drawRectFilled(vec2(bx, byy), vec2(bx + BS, byy + BS * 0.5), rgbm(1, 1, 1, 0.10), 18)
    ui.drawRect(vec2(bx, byy), vec2(bx + BS, byy + BS), rgbm(1, 1, 1, 0.28), 18, nil, 2)
    dwBox("امسك", 20, bx, byy + 18, BS, 24, CW)
    dwMono(keyName(keyStore.rewindKey), 32, bx, byy + BS * 0.5 - 6, BS, 40, CW)
    dwBox(ready and "جاهز للرجوع" or "يسجّل...", 12, bx, byy + BS - 28, BS, 16, ready and CGR or CDm)
  end
  dwBox("امسك المفتاح للرجوع · حماية 10 ثواني بعده", 12, X, byy + BS + 8, W, 16, CC)

  -- ===== لوحة الإعدادات (نفس ستايل البوست) =====
  local gy   = byy + BS + 30
  local setH = math.max((Y + H - 38) - gy, 70)
  ui.setCursor(vec2(X, gy))
  ui.drawRectFilled(vec2(X, gy), vec2(X + W, gy + setH), rgbm(1, 1, 1, 0.028), 12)
  ui.drawRect(vec2(X, gy), vec2(X + W, gy + setH), rgbm(1, 1, 1, 0.06), 12, nil, 1)
  ui.childWindow("##rset", vec2(W, setH), function()
    local ww = ui.windowWidth() - 20
    local ly = 8

    -- سرعة الرجوع
    local nv = rewindSlider("سرعة الرجوع  (مضاعف الزمن)", 10, ly, ww, "##rspd",
      rewindStore.speed, 1, 8, "  x%.1f")
    if math.abs(nv - rewindStore.speed) > 0.01 then rewindStore.speed = nv end
    ly = ly + 44

    -- أزرار جاهزة للسرعة
    local names, sel = {}, 0
    for i, p in ipairs(REWIND_SPEED_PRESETS) do
      names[i] = p[1]
      if math.abs(rewindStore.speed - p[2]) < 0.05 then sel = i end
    end
    local ns = segToggle(10, ly, ww, 32, names, sel)
    if ns ~= sel then rewindStore.speed = REWIND_SPEED_PRESETS[ns][2] end
    ly = ly + 46

    -- مدة التسجيل
    nv = rewindSlider("مدة التسجيل  (كم ثانية يحفظ)", 10, ly, ww, "##rmax",
      rewindStore.maxSec, 5, 60, "  %.0f second")
    if math.abs(nv - rewindStore.maxSec) > 0.01 then rewindStore.maxSec = nv end
    ly = ly + 48

    -- رجوع للافتراضي
    if bigButton(10, ly, ww, 32, "رجوع للإعدادات الافتراضية", rgbm(0.30, 0.31, 0.36, 1), "##rrst") then
      rewindStore.speed  = CFG.REWIND_SPEED * 1.0
      rewindStore.maxSec = CFG.REWIND_MAX_SEC * 1.0
    end
    ly = ly + 40

    dwBox("السرعة الأعلى = رجوع أسرع · المدة الأطول = ذاكرة أطول", 12, 10, ly, ww, 16, CDm)
    ui.dummy(vec2(1, ly + 24))
  end)

  -- ===== المفتاح (يتجنّب مفتاح البوست تلقائياً) =====
  keyPicker(X, Y + H - 30, W, "مفتاح الرجوع", keyName(keyStore.rewindKey), function()
    keyStore.rewindKey = nextKey(keyStore.rewindKey, keyStore.boostKey)
  end)
end

--=================================================================
-- [17] FEATURE: WEATHER  (جو ووقت شخصي)
--   شرط السيرفر: EnableClientMessages: true في extra_cfg.yml
--=================================================================
local driveWeatherEvent = ac.OnlineEvent({
  ac.StructItem.key("driveWeather"),
  command     = ac.StructItem.int32(),   -- 1=weather 2=time 3=reset
  weatherType = ac.StructItem.int32(),   -- قيمة WeatherFxType الخام
  hour        = ac.StructItem.int32(),
  minute      = ac.StructItem.int32(),
}, function(sender, data) end)

-- كل أنواع الجو من CSP تلقائيًا (نفس اجواء comfy)
local wList = {}
for name, id in pairs(ac.WeatherType) do
  if type(id) == "number" and name ~= "None" then
    wList[#wList + 1] = { id = id, name = name }
  end
end
table.sort(wList, function(a, b) return a.name < b.name end)

local wTime     = 720   -- 12:00
local wSel      = -1
local wDirty    = false
local wLastSent = -1

local function wSendWeather(id)
  driveWeatherEvent{ command = 1, weatherType = id, hour = 0, minute = 0 }
  wSel = id
end

local function wSendTime()
  driveWeatherEvent{ command = 2, weatherType = 0, hour = math.floor(wTime / 60), minute = wTime % 60 }
  wLastSent = os.clock()
end

local function wSendReset()
  driveWeatherEvent{ command = 3, weatherType = 0, hour = 0, minute = 0 }
  wSel = -1
end

local function drawWeather(X, Y, W, H)
  sectionTitle("الجو والوقت", "WEATHER", X, Y, W)
  local topY = Y + 46

  -- ===== الوقت (سلايدر: ساعة/دقيقة) =====
  dwLeftBox("الوقت", 13, X, topY, 120, 18, ACC)
  ui.setCursor(vec2(X, topY + 22))
  ui.setNextItemWidth(W)
  ui.pushStyleColor(ui.StyleColor.SliderGrab, ACC)
  ui.pushStyleColor(ui.StyleColor.FrameBg, rgbm(1, 1, 1, 0.05))
  local nv = ui.slider("##wtime", wTime, 0, 1439,
    string.format("  %02d:%02d", math.floor(wTime / 60), wTime % 60))
  ui.popStyleColor(2)
  -- يُرسل فقط عند التحريك الفعلي (ما يرسل عند مجرد فتح التبويب)
  local newT = math.floor(nv)
  if newT ~= wTime then wTime = newT; wDirty = true end
  if wDirty and (os.clock() - wLastSent) > 0.15 then wSendTime(); wDirty = false end

  -- ===== قائمة الأجواء (عمودين، تضغط تختار) =====
  local btnH   = 42
  local resetY = Y + H - btnH
  local listY  = topY + 58
  local listH  = (resetY - 14) - listY
  ui.drawRectFilled(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.028), 12)
  ui.drawRect(vec2(X, listY), vec2(X + W, listY + listH), rgbm(1, 1, 1, 0.06), 12, nil, 1)
  ui.setCursor(vec2(X, listY))
  ui.childWindow("##wlist", vec2(W, listH), function()
    local ww   = ui.windowWidth()
    local colW = (ww - 12) / 2
    for i = 1, #wList do
      local coln = (i - 1) % 2
      local rown = math.floor((i - 1) / 2)
      local bx = 4 + coln * (colW + 4)
      local by = 4 + rown * 40
      ui.setCursor(vec2(bx, by))
      local cl  = ui.invisibleButton("##w" .. wList[i].id, vec2(colW, 36))
      local hov = ui.itemHovered()
      local sel = wSel == wList[i].id
      local bg  = sel and rgbm(ACC.r, ACC.g, ACC.b, 0.9)
                  or (hov and rgbm(1, 1, 1, 0.10) or rgbm(1, 1, 1, 0.04))
      ui.drawRectFilled(vec2(bx, by), vec2(bx + colW, by + 36), bg, 8)
      dwBox(wList[i].name, 14, bx, by, colW, 36, sel and DK or CW)
      if cl then wSendWeather(wList[i].id) end
    end
    ui.dummy(vec2(1, math.ceil(#wList / 2) * 40 + 8))
  end)

  -- ===== رجوع لجو السيرفر =====
  if bigButton(X, resetY, W, btnH, "رجوع لجو السيرفر", ACC, "##wreset") then wSendReset() end
end

--=================================================================
-- [18] FEATURE: SHADDA POINTS  (شدّات ثابتة خاصة باللاعب)
--   اللاعب يوقف بالمكان اللي يبيه، يحفظه في حرف، وبعدها يضغط
--   الحرف في أي وقت فيرسبن عليه. محفوظة محلياً وتبقى بعد الخروج.
--
--   ⚠ لا تستخدم هذي الحروف: T U O K F B (محجوزة لشدّات السيرفر)
--     ولا D (مفتاح القائمة) ولا W A S D (القيادة بالكيبورد).
--=================================================================
local SHADDA_SLOTS = {
  { letter = "H", code = 72 },
  { letter = "V", code = 86 },
  { letter = "L", code = 76 },
  { letter = "J", code = 74 },
}

local shaddaDefaults = {}
for _, s in ipairs(SHADDA_SLOTS) do shaddaDefaults["shadda_" .. s.letter] = "" end
local shaddaStore = ac.storage(shaddaDefaults)
local shaddaPrev  = {}
local shaddaMsg, shaddaMsgT = "", 0

-- الحرف معطّل لو محجوز لمفتاح ثاني في نفس البلقن
local function shaddaBusy(code)
  return code == CFG.MENU_TOGGLE_KEY
      or code == keyStore.boostKey
      or code == keyStore.rewindKey
end

local function shaddaRead(slot)
  local raw = shaddaStore["shadda_" .. slot.letter]
  if not raw or raw == "" then return nil end
  local n = {}
  for v in raw:gmatch("[^,]+") do n[#n + 1] = tonumber(v) end
  if #n < 9 then return nil end
  return vec3(n[1], n[2], n[3]), vec3(n[4], n[5], n[6]), vec3(n[7], n[8], n[9])
end

local function shaddaSave(slot)
  local car = ac.getCar(0)
  if not car then return end
  shaddaStore["shadda_" .. slot.letter] = string.format(
    "%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f",
    car.position.x, car.position.y, car.position.z,
    car.look.x, car.look.y, car.look.z,
    car.up.x, car.up.y, car.up.z)
  shaddaMsg, shaddaMsgT = "تم حفظ المكان في حرف " .. slot.letter, 3
end

local function shaddaClear(slot)
  shaddaStore["shadda_" .. slot.letter] = ""
  shaddaMsg, shaddaMsgT = "تم مسح حرف " .. slot.letter, 3
end

-- نفس طريقة الريوايند بالضبط (مجرّبة وشغّالة): -look مع up
local function shaddaGo(slot)
  if not Core.ready() then return end
  local pos, look, up = shaddaRead(slot)
  if not pos then return end
  physics.setCarVelocity(0, vec3(0, 0, 0))
  physics.setCarPosition(0, pos, -look, up)
  Core.ghostStart()
  Core.startCooldown()
end

local function shaddaUpdate(dt)
  if shaddaMsgT > 0 then shaddaMsgT = shaddaMsgT - dt end
  local typing = isTyping()
  for i, s in ipairs(SHADDA_SLOTS) do
    local down = (not typing) and (not shaddaBusy(s.code)) and ui.keyboardButtonDown(s.code)
    if down and not shaddaPrev[i] then shaddaGo(s) end
    shaddaPrev[i] = down
  end
end

local function drawShadda(X, Y, W, H)
  sectionTitle("الشدّات الثابتة", "SHADDA", X, Y, W)
  dwRightBox("قف بالمكان → احفظ في حرف → اضغط الحرف ترجع له", 12, X, Y + 26, W - 44, 14, CDm)

  local car  = ac.getCar(0)
  local rowH = 58
  local sy   = Y + 52

  for i, s in ipairs(SHADDA_SLOTS) do
    local ry   = sy + (i - 1) * (rowH + 8)
    local pos  = shaddaRead(s)
    local busy = shaddaBusy(s.code)

    ui.drawRectFilled(vec2(X, ry), vec2(X + W, ry + rowH),
      pos and rgbm(ACC.r, ACC.g, ACC.b, 0.10) or rgbm(1, 1, 1, 0.035), 12)
    ui.drawRect(vec2(X, ry), vec2(X + W, ry + rowH), rgbm(1, 1, 1, 0.07), 12, nil, 1)

    -- شارة الحرف
    ui.drawRectFilled(vec2(X + 8, ry + 9), vec2(X + 56, ry + rowH - 9),
      pos and rgbm(ACC.r, ACC.g, ACC.b, 0.85) or rgbm(1, 1, 1, 0.07), 10)
    dwBox(s.letter, 24, X + 8, ry + 9, 48, rowH - 18, pos and DK or CDm)

    -- الأزرار (يمين الصف)
    local bw, bh = 74, 34
    local by = ry + (rowH - bh) * 0.5
    local b3 = X + W - 8 - bw
    local b2 = b3 - bw - 6
    local b1 = b2 - bw - 6

    local canGo = pos ~= nil and Core.ready()
    if bigButton(b1, by, bw, bh, "انتقال", canGo and ACC or rgbm(0.24, 0.25, 0.30, 1), "##shg" .. s.letter) and canGo then
      shaddaGo(s)
    end
    if bigButton(b2, by, bw, bh, "حفظ هنا", rgbm(0.30, 0.31, 0.36, 1), "##shs" .. s.letter) then
      shaddaSave(s)
    end
    if bigButton(b3, by, bw, bh, "مسح", rgbm(0.30, 0.20, 0.20, 1), "##shc" .. s.letter) then
      shaddaClear(s)
    end

    -- الحالة (بين الشارة والأزرار)
    local tx, tw = X + 64, b1 - (X + 64) - 8
    local st, sc
    if busy then
      st, sc = "الحرف محجوز لمفتاح ثاني", CR
    elseif pos then
      local d = car and (car.position:distance(pos)) or 0
      st, sc = string.format("محفوظة · %.0f م", d), CGR
    else
      st, sc = "فارغة", CDm
    end
    dwBox(st, 14, tx, ry, tw, rowH, sc)
  end

  -- رسالة تأكيد قصيرة
  if shaddaMsgT > 0 then
    local my = Y + H - 26
    ui.drawRectFilled(vec2(X, my), vec2(X + W, my + 24), rgbm(ACC.r, ACC.g, ACC.b, 0.14), 7)
    dwBox(shaddaMsg, 13, X, my, W, 24, CC)
  end
end

--=================================================================
-- [20] NAV ICONS  (كل أيقونة دالة مستقلة — نضيفها للتبويب في [21])
--   التوقيع: fn(cx, cy, r, t, c)
--=================================================================
local ICONS = {}

function ICONS.crosshair(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r, c, 32, t)
  ui.drawLine(vec2(cx - r - 3, cy), vec2(cx - r * 0.45, cy), c, t)
  ui.drawLine(vec2(cx + r * 0.45, cy), vec2(cx + r + 3, cy), c, t)
  ui.drawLine(vec2(cx, cy - r - 3), vec2(cx, cy - r * 0.45), c, t)
  ui.drawLine(vec2(cx, cy + r * 0.45), vec2(cx, cy + r + 3), c, t)
  ui.drawCircleFilled(vec2(cx, cy), 2.4, c)
end

function ICONS.map(cx, cy, r, t, c)
  local s = r / 0.34
  local w = s * 0.22
  local h = s * 0.62
  local y1 = cy - h * 0.5
  ui.drawLine(vec2(cx - w * 1.5, y1 + 2), vec2(cx - w * 0.5, y1), c, t)
  ui.drawLine(vec2(cx - w * 0.5, y1), vec2(cx + w * 0.5, y1 + 2), c, t)
  ui.drawLine(vec2(cx + w * 0.5, y1 + 2), vec2(cx + w * 1.5, y1), c, t)
  ui.drawLine(vec2(cx - w * 1.5, y1 + 2), vec2(cx - w * 1.5, y1 + h), c, t)
  ui.drawLine(vec2(cx - w * 0.5, y1), vec2(cx - w * 0.5, y1 + h - 2), c, t)
  ui.drawLine(vec2(cx + w * 0.5, y1 + 2), vec2(cx + w * 0.5, y1 + h), c, t)
  ui.drawLine(vec2(cx + w * 1.5, y1), vec2(cx + w * 1.5, y1 + h - 2), c, t)
  ui.drawLine(vec2(cx - w * 1.5, y1 + h), vec2(cx - w * 0.5, y1 + h - 2), c, t)
  ui.drawLine(vec2(cx - w * 0.5, y1 + h - 2), vec2(cx + w * 0.5, y1 + h), c, t)
  ui.drawLine(vec2(cx + w * 0.5, y1 + h), vec2(cx + w * 1.5, y1 + h - 2), c, t)
end

function ICONS.palette(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r, c, 36, t)
  ui.drawCircleFilled(vec2(cx - 7, cy - 5), 2.3, c)
  ui.drawCircleFilled(vec2(cx + 5, cy - 7), 2.3, c)
  ui.drawCircleFilled(vec2(cx + 8, cy + 2), 2.3, c)
  ui.drawCircleFilled(vec2(cx - 3, cy + 8), 2.3, c)
end

function ICONS.tire(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r, c, 36, t)
  ui.drawCircle(vec2(cx, cy), r * 0.45, c, 24, t)
  for i = 0, 5 do
    local a = math.rad(i * 60)
    ui.drawLine(vec2(cx + math.cos(a) * r * 0.45, cy + math.sin(a) * r * 0.45),
                vec2(cx + math.cos(a) * r * 0.88, cy + math.sin(a) * r * 0.88), c, t)
  end
end

function ICONS.bolt(cx, cy, r, t, c)
  local p1 = vec2(cx - 5, cy - 10)
  local p2 = vec2(cx + 1, cy - 2)
  local p3 = vec2(cx - 2, cy - 2)
  local p4 = vec2(cx + 6, cy + 10)
  local p5 = vec2(cx, cy + 2)
  local p6 = vec2(cx + 3, cy + 2)
  ui.drawLine(p1, p2, c, t)
  ui.drawLine(p2, p3, c, t)
  ui.drawLine(p3, p4, c, t)
  ui.drawLine(p4, p5, c, t)
  ui.drawLine(p5, p6, c, t)
end

function ICONS.gear(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r * 0.75, c, 32, t)
  ui.drawCircle(vec2(cx, cy), r * 0.28, c, 16, t)
  for i = 0, 7 do
    local a = math.rad(i * 45)
    ui.drawLine(vec2(cx + math.cos(a) * r * 0.78, cy + math.sin(a) * r * 0.78),
                vec2(cx + math.cos(a) * r * 1.05, cy + math.sin(a) * r * 1.05), c, t)
  end
end

function ICONS.rewind(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r * 0.95, c, 32, t)
  ui.drawLine(vec2(cx + 5, cy - 6), vec2(cx - 3, cy - 6), c, t)
  ui.drawLine(vec2(cx - 3, cy - 6), vec2(cx - 8, cy), c, t)
  ui.drawLine(vec2(cx - 8, cy), vec2(cx - 3, cy + 6), c, t)
end

function ICONS.pin(cx, cy, r, t, c)
  local top = cy - r * 0.30
  ui.drawCircle(vec2(cx, top), r * 0.58, c, 24, t)
  ui.drawCircleFilled(vec2(cx, top), r * 0.20, c)
  ui.drawLine(vec2(cx - r * 0.42, top + r * 0.40), vec2(cx, cy + r * 0.95), c, t)
  ui.drawLine(vec2(cx + r * 0.42, top + r * 0.40), vec2(cx, cy + r * 0.95), c, t)
end

function ICONS.sun(cx, cy, r, t, c)
  ui.drawCircle(vec2(cx, cy), r * 0.55, c, 24, t)
  for i = 0, 7 do
    local a = math.rad(i * 45)
    ui.drawLine(vec2(cx + math.cos(a) * r * 0.75, cy + math.sin(a) * r * 0.75),
                vec2(cx + math.cos(a) * r * 1.05, cy + math.sin(a) * r * 1.05), c, t)
  end
end

--=================================================================
-- [21] TAB REGISTRY
--   تبي تضيف تبويب؟ سوّ بلوك ميزة فوق، وزد سطر واحد هنا.
--   تبي تشيل تبويب؟ احذف سطره — بدون أي تعديل ثاني.
--=================================================================
-- ===== إعدادات التاق (يقرأها بلوك [29]) + تبويب التحكم =====
local tagStore = ac.storage{ tg_enabled = 1, tg_scale = 1.0, tg_opacity = 1.0, tg_distance = 150.0, tg_flag = 1, tg_height = 1.35 }

local function drawTags(X, Y, W, H)
  local sy = Y
  sectionTitle("تاقات الأسماء", "NAME TAGS", X, sy, W); sy = sy + 50

  -- تشغيل/إيقاف
  do
    local on = tagStore.tg_enabled == 1
    ui.setCursor(vec2(X, sy))
    local cl = ui.invisibleButton("##tgen", vec2(W, 40))
    ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + 40),
      on and rgbm(ACC.r, ACC.g, ACC.b, 0.85) or rgbm(1, 1, 1, 0.05), 10)
    dwBox(on and "التاقات: تعمل" or "التاقات: متوقفة", 15, X, sy, W, 40, on and DK or CW)
    if cl then tagStore.tg_enabled = on and 0 or 1 end
    sy = sy + 50
  end

  -- الحجم
  dwLeftBox("الحجم", 13, X, sy, 120, 18, ACC)
  dwRightBox(string.format("%.0f%%", tagStore.tg_scale * 100), 13, X + W - 90, sy, 90, 18, CDm)
  sy = sy + 22
  ui.setCursor(vec2(X, sy)); ui.setNextItemWidth(W)
  local nsc, csc = ui.slider("##tgsize", tagStore.tg_scale, 0.5, 2.0, "")
  if csc then tagStore.tg_scale = math.clamp(nsc, 0.5, 2.0) end
  sy = sy + 46

  -- الشفافية
  dwLeftBox("الوضوح", 13, X, sy, 120, 18, ACC)
  dwRightBox(string.format("%.0f%%", tagStore.tg_opacity * 100), 13, X + W - 90, sy, 90, 18, CDm)
  sy = sy + 22
  ui.setCursor(vec2(X, sy)); ui.setNextItemWidth(W)
  local nop, cop = ui.slider("##tgopac", tagStore.tg_opacity, 0.15, 1.0, "")
  if cop then tagStore.tg_opacity = math.clamp(nop, 0.15, 1.0) end
  sy = sy + 46

  -- المسافة
  dwLeftBox("مدى الظهور", 13, X, sy, 140, 18, ACC)
  dwRightBox(string.format("%.0f م", tagStore.tg_distance), 13, X + W - 90, sy, 90, 18, CDm)
  sy = sy + 22
  ui.setCursor(vec2(X, sy)); ui.setNextItemWidth(W)
  local nds, cds = ui.slider("##tgdist", tagStore.tg_distance, 30, 400, "")
  if cds then tagStore.tg_distance = math.clamp(nds, 30, 400) end
  sy = sy + 46

  -- الارتفاع فوق السيارة (متر)
  dwLeftBox("ارتفاع التاق", 13, X, sy, 140, 18, ACC)
  dwRightBox(string.format("%.2f م", tagStore.tg_height), 13, X + W - 90, sy, 90, 18, CDm)
  sy = sy + 22
  ui.setCursor(vec2(X, sy)); ui.setNextItemWidth(W)
  local nhg, chg = ui.slider("##tghgt", tagStore.tg_height, 0.2, 3.0, "")
  if chg then tagStore.tg_height = math.clamp(nhg, 0.2, 3.0) end
  sy = sy + 46

  -- العلم
  do
    local on = tagStore.tg_flag == 1
    ui.setCursor(vec2(X, sy))
    local cl = ui.invisibleButton("##tgflag", vec2(W, 36))
    ui.drawRectFilled(vec2(X, sy), vec2(X + W, sy + 36),
      on and rgbm(ACC.r, ACC.g, ACC.b, 0.6) or rgbm(1, 1, 1, 0.05), 10)
    dwBox(on and "علم الدولة: ظاهر" or "علم الدولة: مخفي", 14, X, sy, W, 36, on and DK or CW)
    if cl then tagStore.tg_flag = on and 0 or 1 end
    sy = sy + 44
  end

  dwBox("التغييرات تنحفظ تلقائياً", 12, X, sy + 4, W, 16, CDm)
end

local TABS = {
  { key = "teleport", label = "الانتقال", icon = ICONS.crosshair, draw = drawTeleport },
  { key = "shadda",   label = "الشدّات",  icon = ICONS.pin,       draw = drawShadda   },
  { key = "map",      label = "الخريطة",  icon = ICONS.map,       draw = drawMap      },
  { key = "skins",    label = "السكنات",  icon = ICONS.palette,   draw = drawSkin     },
  { key = "grip",     label = "التماسك",  icon = ICONS.tire,      draw = drawGrip     },
  { key = "boost",    label = "البوست",   icon = ICONS.bolt,      draw = drawBoost    },
  { key = "extras",   label = "الأكسترا", icon = ICONS.gear,      draw = drawExtras   },
  { key = "rewind",   label = "الرجوع",   icon = ICONS.rewind,    draw = drawRewind   },
  { key = "weather",  label = "الجو",     icon = ICONS.sun,       draw = drawWeather  },
  { key = "tags",     label = "التاق",    icon = ICONS.gear,      draw = drawTags     },
}

--=================================================================
-- [22] PANEL SHELL  (اللوقو + عمود التبويبات + الهيدر + التوزيع)
--=================================================================
local activeTab     = 1
local panelOpen     = not CFG.START_CLOSED
local lastDrawClock = 0
local firstDraw     = true

local function drawLogo(x0, y0, x1, y1)
  local boxW, boxH = x1 - x0, y1 - y0
  if CFG.LOGO_URL ~= "" then
    local sz = ui.imageSize(CFG.LOGO_URL)
    if sz and sz.x > 1 and sz.y > 1 then
      local sc = math.min(boxW / sz.x, boxH / sz.y)
      local dw, dh = sz.x * sc, sz.y * sc
      local ix, iy = x0 + (boxW - dw) * 0.5, y0 + (boxH - dh) * 0.5
      ui.drawImage(CFG.LOGO_URL, vec2(ix, iy), vec2(ix + dw, iy + dh))
      return
    else
      ui.decodeImage(CFG.LOGO_URL)
    end
  end
  dwBox("DRIVE", 26, x0, y0, boxW, boxH, CW)
end

local panelBody   -- معرّف تحت (جسم البانل المشترك)

local function mainUI()
  -- إذا توقفت اللعبة عن رسم النافذة (أُغلقت من قائمة التطبيقات) ثم أعادت إظهارها،
  -- نعيد فتح البانل تلقائياً حتى لا يطلع "شبح" فاضي ويظنّه اللاعب معلّقاً.
  -- نتخطى هذا في أول فريم فقط، عشان الدخول يكون بقائمة مقفولة وتنبيه D يبان.
  if firstDraw then
    firstDraw = false
  elseif Core.clock - lastDrawClock > 0.3 then
    panelOpen = true
  end
  lastDrawClock = Core.clock

  -- حالة الإغلاق: مخفية تماماً (تُفتح بزر  D )
  if not panelOpen then
    pcall(function() ui.setWindowSize(vec2(1, 1)) end)
    ui.setCursor(vec2(0, 0)); ui.dummy(vec2(1, 1))
    return
  end

  panelBody()
end

-- جسم البانل نفسه (يرسم من الاكسترا أو من المضيف الدائم [28] — نفس الكود للاثنين)
panelBody = function()
  -- الحجم الفعلي للنافذة (تتحجّم بالسحب الطبيعي من الزاوية/الحواف)
  local ws = ui.windowSize()
  local W = math.max(ws.x, CFG.PANEL_MIN_W)
  local H = math.max(ws.y, CFG.PANEL_MIN_H)

  -- خلفية + توهج علوي
  ui.drawRectFilled(vec2(0, 0), vec2(W, H), BGD, 14)
  for s = 1, 3 do
    ui.drawRectFilled(vec2(0, 0), vec2(W, 80 + s * 22), rgbm(ACC.r, ACC.g, ACC.b, 0.015), 14)
  end
  ui.drawRect(vec2(0, 0), vec2(W, H), rgbm(1, 1, 1, 0.09), 14, nil, 1)

  -- ===== العمود الأيسر =====
  local NAV = CFG.NAV_W
  drawLogo(14, 16, NAV - 14, 62)
  ui.drawLine(vec2(NAV, 16), vec2(NAV, H - 16), rgbm(1, 1, 1, 0.07), 1)

  local itemH = 48
  local ny0 = 84
  for i, tab in ipairs(TABS) do
    local iy = ny0 + (i - 1) * (itemH + 6)
    ui.setCursor(vec2(10, iy))
    local cl  = ui.invisibleButton("##nv" .. tab.key, vec2(NAV - 20, itemH))
    local hov = ui.itemHovered()
    local sel = activeTab == i
    if sel then
      ui.drawRectFilled(vec2(10, iy), vec2(NAV - 10, iy + itemH), rgbm(ACC.r, ACC.g, ACC.b, 0.18), 12)
      ui.drawRectFilled(vec2(10, iy), vec2(NAV - 10, iy + itemH), rgbm(ACC.r, ACC.g, ACC.b, 0.06), 12)
      ui.drawRectFilled(vec2(NAV - 13, iy + 10), vec2(NAV - 10, iy + itemH - 10), ACC, 2)
    elseif hov then
      ui.drawRectFilled(vec2(10, iy), vec2(NAV - 10, iy + itemH), rgbm(1, 1, 1, 0.05), 12)
    end
    -- الأيقونة أقصى اليمين، والنص يسارها مع مسافة واضحة (ما يتداخلون)
    local ix = NAV - 40
    local iyy = iy + (itemH - 22) * 0.5
    tab.icon(ix + 11, iyy + 11, 22 * 0.34, math.max(1.5, 22 * 0.08), sel and ACC or CDm)
    dwRightBox(tab.label, 16, 8, iy, NAV - 58, itemH, sel and CW or CDm)
    if cl then activeTab = i end
  end
  dwBox("غلق: زر  " .. CFG.MENU_KEY_LABEL, 11, 0, H - 40, NAV, 14, CDm)
  dwBox("DRIVE © v8.8", 10, 0, H - 22, NAV, 12, CDm)   -- رقم النسخة: تأكد إنه يبان بعد التركيب

  -- ===== الشريط العلوي: حالة + إخفاء الشعارات + إغلاق =====
  local CX = NAV + 16
  local CWid = W - CX - 16
  dwBox("● ONLINE", 11, CX, 14, 100, 16, CGR)

  -- زر تبديل إخفاء/إظهار شعارَي "اضغط D/C" (يفيد وقت البث مثلاً)
  do
    local hidden = hintStor.hide_hints
    ui.setCursor(vec2(W - 80, 12))
    local hcl = ui.invisibleButton("##hideHints", vec2(30, 30))
    local hhov = ui.itemHovered()
    ui.drawRectFilled(vec2(W - 80, 12), vec2(W - 50, 42), hhov and rgbm(1, 1, 1, 0.10) or rgbm(1, 1, 1, 0.06), 8)
    ui.drawRect(vec2(W - 80, 12), vec2(W - 50, 42), rgbm(1, 1, 1, 0.12), 8, nil, 1)
    local ecx, ecy = W - 65, 27
    local ecol = hidden and CDm or ACC
    ui.drawCircle(vec2(ecx, ecy), 7, ecol, 24, 1.6)
    if hidden then
      ui.drawLine(vec2(ecx - 8, ecy - 8), vec2(ecx + 8, ecy + 8), ecol, 1.8)
    else
      ui.drawCircleFilled(vec2(ecx, ecy), 2.6, ecol)
    end
    if hcl then hintStor.hide_hints = not hidden end
  end

  ui.setCursor(vec2(W - 42, 12))
  local xcl = ui.invisibleButton("##close", vec2(30, 30))
  local xhov = ui.itemHovered()
  ui.drawRectFilled(vec2(W - 42, 12), vec2(W - 12, 42), xhov and rgbm(0.9, 0.25, 0.2, 0.95) or rgbm(1, 1, 1, 0.06), 8)
  ui.drawRect(vec2(W - 42, 12), vec2(W - 12, 42), rgbm(1, 1, 1, 0.12), 8, nil, 1)
  ui.drawLine(vec2(W - 36, 18), vec2(W - 18, 36), xhov and CW or CDm, 2)
  ui.drawLine(vec2(W - 18, 18), vec2(W - 36, 36), xhov and CW or CDm, 2)
  if xcl then panelOpen = false end

  -- ===== شريط الحالة (حماية / انتظار) =====
  local CY0 = 46
  if Core.ghostOn then
    ui.drawRectFilled(vec2(CX, CY0), vec2(CX + CWid, CY0 + 22), rgbm(ACC.r, ACC.g, ACC.b, 0.12), 7)
    dwBox(string.format("● حماية  %.1f", Core.ghostT), 13, CX, CY0, CWid, 22, CC)
    CY0 = CY0 + 26
  end
  if Core.cd > 0 then
    ui.drawRectFilled(vec2(CX, CY0), vec2(CX + CWid, CY0 + 22), rgbm(CY.r, CY.g, CY.b, 0.12), 7)
    dwBox(string.format("● انتظار  %.1f", Core.cd), 13, CX, CY0, CWid, 22, CY)
    CY0 = CY0 + 26
  end
  local CHt = H - CY0 - 18

  -- ===== محتوى التبويب النشط =====
  local tab = TABS[activeTab]
  if tab and tab.draw then tab.draw(CX, CY0, CWid, CHt) end

  -- علامة زاوية التحجيم (اسحب الزاوية لتكبير/تصغير النافذة)
  local gc = CDm
  ui.drawLine(vec2(W - 7, H - 24), vec2(W - 24, H - 7), gc, 1.6)
  ui.drawLine(vec2(W - 7, H - 17), vec2(W - 17, H - 7), gc, 1.6)
  ui.drawLine(vec2(W - 7, H - 10), vec2(W - 10, H - 7), gc, 1.6)

  ui.setCursor(vec2(0, 0))
  ui.dummy(vec2(W, H))
end

--=================================================================
-- [23] REGISTER APP
--   بلا تايتل بار وبلا تحكّم CSP (الإغلاق من الزر الداخلي)
--=================================================================
local winFlags = ui.WindowFlags.NoTitleBar
               + ui.WindowFlags.NoBackground
               + ui.WindowFlags.NoScrollbar
               + ui.WindowFlags.NoCollapse

ui.registerOnlineExtra(
  ui.Icons.Navigation,
  "DRIVE | MENU",
  nil,
  mainUI,
  nil,
  ui.OnlineExtraFlags.Tool,
  winFlags,
  vec2(CFG.PANEL_W, CFG.PANEL_H)
)

--=================================================================
-- [28] ALWAYS-ON MENU HOST  (المضيف الدائم للمنيو)
--   يرسم المنيو مباشرة من script.drawUI حتى لو ما فعّلت
--   "DRIVE | MENU" من قائمة الاكسترا — زر D يفتحه دايم.
--   لو الاكسترا مفعّلة وترسم، هذا البلوك يسكت تلقائياً (بدون تكرار).
--=================================================================
local hostStor = ac.storage{ mh_x = -1.0, mh_y = -1.0, mh_w = 0.0, mh_h = 0.0 }
local host = { drag = false, dragOff = vec2(0, 0), sizing = false, gripStart = vec2(0, 0), sizeStart = vec2(0, 0) }

local function drawMenuHost()
  if not panelOpen then return end
  if Core.clock - lastDrawClock < 0.3 then return end   -- الاكسترا نفسها ترسم — لا تكرر
  local sim = ac.getSim()
  if not sim then return end
  local W = math.max(CFG.PANEL_MIN_W, (hostStor.mh_w > 0) and hostStor.mh_w or CFG.PANEL_W)
  local H = math.max(CFG.PANEL_MIN_H, (hostStor.mh_h > 0) and hostStor.mh_h or CFG.PANEL_H)
  local px, py = hostStor.mh_x, hostStor.mh_y
  if px < 0 or py < 0 then
    px = (sim.windowWidth - W) * 0.5
    py = (sim.windowHeight - H) * 0.5
  end
  px = math.max(0, math.min(sim.windowWidth - 80, px))
  py = math.max(0, math.min(sim.windowHeight - 60, py))
  -- (true, true) = بدون حواف + استقبال الضغطات — بدونها الأزرار داخل النافذة ما تستجيب
  ui.transparentWindow("driveMenuHost", vec2(px, py), vec2(W, H), true, true, function()
    panelBody()
    local mlp = ui.mouseLocalPos()
    -- سحب من الشريط العلوي (ما عدا زر الإغلاق يمين)
    if ui.mouseClicked(ui.MouseButton.Left) and not host.drag and not host.sizing
       and mlp.y >= 0 and mlp.y <= 44 and mlp.x >= 0 and mlp.x <= (W - 50) and not ui.anyItemActive() then
      host.drag = true; host.dragOff = vec2(mlp.x, mlp.y)
    end
    if host.drag then
      if ui.mouseDown(ui.MouseButton.Left) then
        local mp = ui.mousePos()
        hostStor.mh_x = mp.x - host.dragOff.x
        hostStor.mh_y = mp.y - host.dragOff.y
      else host.drag = false end
    end
    -- تحجيم من الزاوية السفلية اليمنى (نفس علامة التحجيم المرسومة)
    local overGrip = mlp.x >= (W - 26) and mlp.x <= W and mlp.y >= (H - 26) and mlp.y <= H
    if overGrip and ui.mouseDown(ui.MouseButton.Left) and not host.sizing and not host.drag then
      host.sizing = true; host.gripStart = ui.mousePos(); host.sizeStart = vec2(W, H)
    end
    if host.sizing then
      if ui.mouseDown(ui.MouseButton.Left) then
        local mp = ui.mousePos()
        hostStor.mh_w = math.max(CFG.PANEL_MIN_W, host.sizeStart.x + (mp.x - host.gripStart.x))
        hostStor.mh_h = math.max(CFG.PANEL_MIN_H, host.sizeStart.y + (mp.y - host.gripStart.y))
      else host.sizing = false end
    end
  end)
end

--=================================================================
-- [24] UPDATE LOOP
--   كل ميزة لها دالة update خاصة — ننادي عليها من هنا فقط.
--=================================================================
local menuPrevKey = false

--=================================================================
-- [26] DRIVE CHAT  (شات HTML — متصفح CSP — زر C)
--=================================================================
-- الواجهة صفحة chat.html على GitHub Pages (نفس معمارية IDDL):
--   JS  -> Lua : AC.send('Drivechat', 'cmd:...')   => browser:onReceive('Drivechat')
--   Lua -> JS  : browser:sendAsync('event', data)  => window.DriveChat[event]
-- فقاعات الإشعارات (لما الشات مقفول) ترسم Native وتُقفل/تُفتح من زر 🔔 داخل الصفحة.
local __dcOk, DriveChat = pcall(function()
  -- ===== إعدادات =====
  local KEY      = string.byte("C")
  local CHAT_URL = "https://iimoovs.github.io/DriveScripts/chat_1.html"
  -- ديسكورد (اختياري — خلّه "" للتعطيل):
  local ADMIN_WEBHOOK   = "https://discord.com/api/webhooks/1536077079446294588/EXaBQ2dv9hJwU8EHRNDxCM6VJZHL42XQfGq9ytBjKefZzhxHCds_DqHMn7LgMED3IESH"   -- ويب هوك روم «تواصل مع الإدارة» (زر 📨 داخل الشات)
  local CHATLOG_WEBHOOK = "https://discord.com/api/webhooks/1536076922402902087/rNy5tdYAdkRS7baBkKu0sb56nowE5TfpueIG2JgitqBF9_z7vNXbpUcsVCq7uwsauVQ_"   -- ويب هوك روم مراقبة الشات (كل رسالة يرسلها اللاعب توصل هناك)
  local RANKS_URL       = "http://91.218.66.157:3050/drive/ranks"  -- رابط API البوت للرتب/الربط مثال: http://IP:3050/drive/ranks
  local ADMIN_NAMES     = {}  -- fallback محلي لو ما فيه API — مثال: { ["AZOOZ"] = "admin" }

  local ACC  = rgbm(1.00, 0.45, 0.06, 1)   -- برتقالي هوية DRIVE
  local CY   = rgbm(1.00, 0.84, 0.20, 1)   -- أصفر هوية DRIVE
  local CW   = rgbm.colors.white
  local CDm  = rgbm(0.66, 0.67, 0.70, 1)
  local FONT = "Segoe UI;Weight=Bold"
  local NOOP = function() end

  local cStor = ac.storage{ dc_notif = true, dc_posX = -1, dc_posY = -1, dc_opacity = 1.0, dc_logX = 16, dc_logY = -1 }
  -- حجم ثابت لنافذة الشات — بنفس فكرة IDDL: بدون تحجيم أبداً (فقط سحب/تحريك)، فيتجنّب كل مشاكل
  -- إعادة البناء/فقدان الرسائل/عدم الاستجابة اللي يسببها تحجيم متصفح CSP
  local CHAT_W, CHAT_H = 920, 620

  -- ===== الستيكرز / GIF =====
  -- نفس القائمة عند كل العملاء — نرسل رقم فقط ($STICK:N) لأن روابط GIF أطول من حد رسائل AC.
  -- (القائمتان تنعرضان بتابين منفصلين داخل الصفحة)
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
  }
  local GIFS = {
    "https://media.wired.com/photos/593221d8b8eb31692072dedf/3:2/w_2560%2Cc_limit/MJ-giphy.gif",
    "https://www.thisiscolossal.com/wp-content/uploads/2014/03/120430.gif",
  }
  local ALLPICS, PICIDX = {}, {}
  for _, u in ipairs(STICKERS) do ALLPICS[#ALLPICS + 1] = u end
  for _, u in ipairs(GIFS)     do ALLPICS[#ALLPICS + 1] = u end
  for i, u in ipairs(ALLPICS)  do PICIDX[u] = i end

  -- ===== الحالة =====
  local S = {
    browser = nil, ready = false, initSent = false,
    open = false, wantsKbd = false, overlayOpen = false,
    navRetries = 0, lastNav = 0, lastOk = 0, clock = 0,
    pos = nil, W = CHAT_W, H = CHAT_H, dragging = false, dragOff = vec2(0, 0), prevKey = false,
    lastPush = 0, lastRanks = -999, ranks = {}, joined = {}, msgId = 0,
    -- [3-CHAT] شات الكلان + الشات الخاص
    clanChatMaxId = 0, dmLastId = {}, activeDmWith = nil, lastMsgPoll = -999,
    seen = {}, jsMode = false, acked = false, readyAt = 0,
    inputSaved = false, savedInput = nil,
    log = {}, chatReveal = 1, logDrag = false, logDragStart = vec2(0, 0), logOfsStart = vec2(0, 0),
  }
  local LOG_MAX = 60

  local function myName() return ac.getDriverName(0) or "أنت" end
  local function rankOf(nm)
    local r = S.ranks[nm]
    return (r and r.rank) or ADMIN_NAMES[nm] or ""
  end
  local function jsonStr(s)
    if not s then return '""' end
    return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '') .. '"'
  end

  -- ===== ناقل Lua -> JS (قناتين: sendAsync الأساسية + javascript: للطوارئ) =====
  local B64C = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local function b64(data)
    return ((data:gsub('.', function(x)
      local r, b = '', x:byte()
      for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
      return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
      if #x < 6 then return '' end
      local c = 0
      for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
      return B64C:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
  end
  local function jval(v)
    local t = type(v)
    if t == 'string' then return jsonStr(v) end
    if t == 'number' then return tostring(v) end
    if t == 'boolean' then return v and 'true' or 'false' end
    if t == 'table' then
      if #v > 0 or next(v) == nil then
        local parts = {}
        for i = 1, #v do parts[#parts + 1] = jval(v[i]) end
        return '[' .. table.concat(parts, ',') .. ']'
      else
        local parts = {}
        for k, val in pairs(v) do parts[#parts + 1] = jsonStr(tostring(k)) .. ':' .. jval(val) end
        return '{' .. table.concat(parts, ',') .. '}'
      end
    end
    return 'null'
  end
  local function jsend(event, data, cb)
    if not S.browser then return end
    if S.jsMode then
      -- وضع الطوارئ: sendAsync ما وصلت للصفحة — ننفذ مباشرة عبر javascript: URL
      pcall(function()
        local payload = b64(jval({ e = event, d = data }))
        S.browser:navigate("javascript:try{DCRX('" .. payload .. "')}catch(e){}")
      end)
      if cb then pcall(cb) end
    else
      pcall(function() S.browser:sendAsync(event, data, cb or NOOP) end)
    end
  end

  -- ===== دفع رسالة للصفحة =====
  local function toBrowser(m)
    if not (S.browser and S.ready) then return end
    local r = S.ranks[m.name]
    jsend('dcMessage', {
      id = m.id or 0,
      name = m.name, rawName = m.name, text = m.text or false, sticker = m.sticker or false,
      srv = m.srv or false, mine = m.mine or false,
      rank = (m.srv and "") or rankOf(m.name),
      rankColor = (r and r.color) or false,
      avatar = (r and r.avatar) or false,
      discord = (r and r.discord) or false,
    })
  end
  local function pushLog(m)
    S.msgId = S.msgId + 1
    m.id = S.msgId
    S.log[#S.log + 1] = m
    while #S.log > LOG_MAX do table.remove(S.log, 1) end
  end
  local function ownMsg(text, sticker)
    -- الصفحة تعرض رسالتك محلياً بنفسها — هنا نسجلها للفقاعات فقط
    pushLog({ name = myName(), text = text, sticker = sticker, srv = false, mine = true, t = S.clock })
  end

  -- ===== ويب هوك ديسكورد =====
  local function relayChatLog(txt)
    if CHATLOG_WEBHOOK == "" then return end
    pcall(function()
      local body = '{"content":' .. jsonStr("**" .. myName() .. "**: " .. txt) .. '}'
      web.post(CHATLOG_WEBHOOK, { ['Content-Type'] = 'application/json' }, body, NOOP)
    end)
  end
  local function sendAdminMsg(txt)
    if ADMIN_WEBHOOK == "" then
      if S.browser and S.ready then jsend('dcAdminAck', { ok = false, reason = 'disabled' }) end
      return
    end
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
      if S.browser and S.ready then jsend('dcAdminAck', { ok = (err == nil) }) end
    end)
  end

  -- ===== الربط الآمن مع الديسكورد (/link داخل الشات) =====
  -- الفكرة: الكود يتولد داخل اللعبة ويظهر لك أنت فقط، وترسله بالديسكورد !verify
  -- كذا مستحيل أحد يربط اسمك بحسابه — لأن الكود ما يظهر إلا على شاشتك.
  -- رسالة نظام عامة (تنخزن بالسجل — تنعرض لأي أحد يفتح الشات لاحقاً)
  local function sysMsg(t)
    local m = { name = "DRIVE", text = t, srv = true, t = S.clock }
    pushLog(m); toBrowser(m)
  end
  -- ⚠️ رسالة نظام خاصة: تُعرض على شاشتي فقط ولا تُخزَّن أبداً في S.log
  -- (السجل يُزامَن للاعبين الجدد عند فتح الشات — فأي شي حساس مثل كود /link
  --  يجب ألا يمر عليه إطلاقاً وإلا انتشر للجميع).
  local function privMsg(t)
    if not (S.browser and S.ready) then return end
    -- نرسمها مباشرة على صفحتي فقط، بدون pushLog، وبدون أي بث
    jsend('dcMessage', { name = "DRIVE", text = t, srv = true, mine = false,
      rank = "", rankColor = false, avatar = false, discord = false })
  end
  -- إرسال لايك للاعب (المرحلة ب) — البوت يمنع التكرار بهوية اللايكر
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
        if S.browser and S.ready then
          jsend('dcLikeAck', { ok = ok and true or false, likes = likes or false, reason = reason or false, target = targetName })
        end
      end)
    end)
  end

  -- حفظ وصف البروفايل (المرحلة ب)
  -- ترميز URL للأسماء (مسافات/رموز عربية) — ضروري لطلبات GET
  local function urlEncode(s)
    s = tostring(s or "")
    return (s:gsub("[^%w%-_%.~]", function(c)
      return string.format("%%%02X", string.byte(c))
    end))
  end

  -- ===== جسر الكلانات =====
  -- POST لأي endpoint كلان مع اسمي، والرد يرجع للصفحة عبر dcClanAck
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
        if S.browser and S.ready then
          jsend('dcClanAck', { ok = ok and true or false, reason = reason or false, msg = okMsg or false })
        end
        -- بعد أي عملية، حدّث حالة كلاني + أجبر تحديث الرتب فوراً (بدل انتظار الدورة)
        if ok then clanFetchMine(); S.lastRanks = 0 end
      end)
    end)
  end

  -- جلب حالة كلاني + دعواتي → dcClanMine
  function clanFetchMine()
    if RANKS_URL == "" then return end
    local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
    local url = base .. '/drive/clan/mine?name=' .. urlEncode(myName())
    pcall(function()
      web.get(url, function(err, resp)
        if not err and resp and resp.body then
          pcall(function()
            local d = JSON.parse(resp.body)
            if d and d.ok and S.browser and S.ready then
              jsend('dcClanMine', { clan = d.clan or false, isOwner = d.isOwner or false, isCoLeader = (d.isCoLeader == true), invites = d.invites or {}, canCreate = (d.canCreate == true) })
            end
          end)
        end
      end)
    end)
  end

  -- تفاصيل كلان بالاسم → dcClanDetails
  -- جلب إيموجيات الكلانات المتاحة → dcClanEmojis
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
            if d and d.ok and S.browser and S.ready then
              jsend('dcClanEmojis', { takenIdx = d.takenIdx or {}, unlockedSlots = d.unlockedSlots, perRow = d.perRow })
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
            if d and S.browser and S.ready then
              jsend('dcClanDetails', { clan = d.clan or false })
            end
          end)
        end
      end)
    end)
  end

  -- ═══════════ [3-CHAT] شات الكلان + الشات الخاص (محفوظان دائماً على البوت) ═══════════
  -- يضيف صورة الحساب + الرتبة الحية لكل رسالة (من S.ranks) — عشان المرتبطين بديسكورد
  -- تبان صورتهم الحقيقية بدل الحرف الأول، بنفس طريقة الشات العام بالضبط
  -- تشخيص: نسجّل أول فشل اتصال بكل نقطة (مرة وحدة بس، عشان ما نغرق اللوق) —
  -- يساعدنا نميّز "الأدونز مو مركّب/البوت مو مشتغل" عن مشكلة بالواجهة
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
        avatar = (r and r.avatar) or nil,
        rank = (r and r.rank) or nil,
        rankColor = (r and r.color) or nil,
      }
    end
    return out
  end

  -- جلب رسائل شات الكلان الجديدة (تراكمي منذ S.clanChatMaxId) — أول مرة تجيب التاريخ كامل
  -- تجميعة واحدة: شات الكلان + قائمة الخاص + المحادثة المفتوحة — بطلب HTTP واحد بدل ٣
  -- (كانت ٣ طلبات منفصلة كل ٤ ثواني لكل لاعب تثقّل على البوت مع كثرة اللاعبين، تسبب
  -- تأخر/فشل متقطع بجلب الرتب نفسها اللي كل الشاتات الثلاث تعتمد عليها لصور البروفايل)
  local function pollMessages()
    if RANKS_URL == "" then return end
    local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
    local nm = myName()
    if nm == "" then return end
    local clanSince = S.clanChatMaxId or 0
    local withName = S.activeDmWith
    local dmSince = 0
    if withName and withName ~= "" then
      S.dmLastId = S.dmLastId or {}
      dmSince = S.dmLastId[withName] or 0
    end
    local url = base .. '/drive/messages/poll?name=' .. urlEncode(nm)
      .. '&clanSince=' .. tostring(clanSince) .. '&dmSince=' .. tostring(dmSince)
    if withName and withName ~= "" then url = url .. '&dmWith=' .. urlEncode(withName) end
    pcall(function()
      web.get(url, function(err, resp)
        if err or not resp then msgDiag('messages/poll', err); return end
        pcall(function()
          local d = JSON.parse(resp.body)
          if not (d and d.ok and S.browser and S.ready) then return end
          -- ملاحظة: ما نحدّث S.clanChatMaxId/S.dmLastId هنا بعد — نجاح الجلب من البوت
          -- ما يعني إن الدفع للصفحة نجح. الصفحة نفسها تخبرنا بأعلى id استلمته فعلاً
          -- عبر chatsync: (كل ٣ ثواني)، وهذا هو المرجع الوحيد لتقديم المؤشر. لو رسالة
          -- ضاعت بالطريق، الدورة الجاية تعيد جلبها تلقائياً بدل ما تضيع للأبد.
          if d.clanMessages and #d.clanMessages > 0 then
            jsend('dcClanChat', enrichMsgs(d.clanMessages))
          end
          jsend('dcDmList', d.dmList or {})
          if withName and withName ~= "" and d.dmMessages and #d.dmMessages > 0 then
            jsend('dcDmMsgs', { withName = withName, messages = enrichMsgs(d.dmMessages) })
          end
        end)
      end)
    end)
  end

  -- إرسال رسالة لشات الكلان (نص أو ملصق) — يجيب فوراً بعد الإرسال (ما ننتظر الدورة)
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

  -- إرسال رسالة خاصة (نص أو ملصق) — يجيب فوراً بعد الإرسال
  local function dmSend(targetName, text, sticker)
    if RANKS_URL == "" then return end
    local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
    local body
    if sticker then body = '{"name":' .. jsonStr(myName()) .. ',"targetName":' .. jsonStr(targetName) .. ',"sticker":' .. jsonStr(sticker) .. '}'
    else body = '{"name":' .. jsonStr(myName()) .. ',"targetName":' .. jsonStr(targetName) .. ',"text":' .. jsonStr(text) .. '}' end
    S.activeDmWith = targetName
    pcall(function()
      web.post(base .. '/drive/dm/send', { ['Content-Type'] = 'application/json' }, body, function(err, resp)
        pollMessages()
      end)
    end)
  end

  -- قبول/رفض محادثة معلّقة
  local function dmRespond(withName, accept)
    if RANKS_URL == "" then return end
    local base = RANKS_URL:gsub('/drive/ranks%s*$', '')
    local body = '{"name":' .. jsonStr(myName()) .. ',"withName":' .. jsonStr(withName) .. ',"accept":' .. (accept and 'true' or 'false') .. '}'
    pcall(function()
      web.post(base .. '/drive/dm/respond', { ['Content-Type'] = 'application/json' }, body, function(err, resp)
        pollMessages()
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
        -- نرسل الوصف كنص فعلي حتى لو فاضي (hasDesc يميّز الفاضي المقصود عن عدم وصول رد)
        if S.browser and S.ready then
          jsend('dcDescAck', { ok = ok and true or false, desc = desc, hasDesc = hasDesc })
        end
        if ok then S.lastRanks = 0 end   -- تحديث فوري (بدل انتظار الدورة)
      end)
    end)
  end

  local function startDiscordLink()
    -- كل رسائل الربط خاصة (privMsg) — الكود لا يمر على السجل ولا يُبث لأحد
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

  -- ===== الرتب / الربط من البوت =====
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

  -- ===== فتح/قفل =====
  local function openChat()
    S.open = true
    if S.browser and S.ready then jsend('dcFocus', true) end
  end
  local function closeChat()
    S.open = false; S.wantsKbd = false; S.dragging = false
    if S.browser and S.ready then jsend('dcBlur', true) end
  end

  local function markReady()
    S.ready = true
    S.initSent = false
    S.lastOk = S.clock
    S.acked = false
    S.readyAt = S.clock
  end

  -- ===== أوامر الصفحة (JS -> Lua) =====
  local function handleData(data)
    -- أي رسالة توصل من الصفحة = دليل حقيقي إنها حية (أوثق من انتظار رد sendAsync
    -- اللي قد ما يشتغل صح مع CEF الجديد بـ CSP 0.3.0 ويسبب إعادة تحميل كل 60 ثانية بالغلط)
    S.lastOk = S.clock
    if data == 'ready' then markReady(); return end
    if data == 'ack' then S.acked = true; return end
    -- مزامنة الرسائل: الصفحة ترسل أعلى id عندها، ونعيد دفع أي رسالة أحدث (استرجاع المفقود)
    if data:sub(1, 8) == 'msgsync:' then
      local haveId = tonumber(data:sub(9)) or 0
      for _, m in ipairs(S.log) do
        -- رسائلي أنا الصفحة تعرضها محلياً فور الإرسال (بدون id) — لا نعيد دفعها هنا
        -- (كانت تتكرر عندي بس: الصفحة ما تعرف id نسختها المحلية فتظنها ناقصة وتطلبها، فتتكرر)
        if (m.id or 0) > haveId and not m.mine then toBrowser(m) end
      end
      return
    end
    -- نفس فكرة msgsync، بس لشات الكلان والخاص: الصفحة تخبرنا بأعلى id استلمته فعلاً
    -- (رسمته)، وهذا يصير المرجع الوحيد لتقديم المؤشر — نفس منطق الفقاعات الموثوق
    if data:sub(1, 9) == 'chatsync:' then
      local okp, obj = pcall(function() return JSON.parse(data:sub(10)) end)
      if okp and obj then
        if obj.clan ~= nil then S.clanChatMaxId = math.max(S.clanChatMaxId or 0, tonumber(obj.clan) or 0) end
        if obj.dmWith and obj.dmWith ~= "" and obj.dm ~= nil then
          S.dmLastId = S.dmLastId or {}
          S.dmLastId[obj.dmWith] = math.max(S.dmLastId[obj.dmWith] or 0, tonumber(obj.dm) or 0)
        end
      end
      return
    end
    if data:sub(1, 4) == 'kbd:' then S.wantsKbd = (data:sub(5) == '1'); return end
    -- الصفحة تخبرنا لما تفتح نافذة منبثقة (بروفايل/كلان/إدارة) عشان نوقف سحب النافذة
    -- (زر X فيها كان يقع بمنطقة سحب الهيدر ويُبلع كسحب بدل ما يوصل للصفحة)
    if data:sub(1, 4) == 'ovl:' then S.overlayOpen = (data:sub(5) == '1'); return end
    if data:sub(1, 5) == 'send:' then
      local msg = data:sub(6)
      if msg == '' then return end
      -- أمر الربط: /link — ما ينرسل للشات العام، بس يولد كود التحقق
      local ml = msg:lower()
      if ml == '/link' or ml == '/ربط' or ml == 'link/' then
        startDiscordLink()
        return
      end
      ownMsg(msg, nil)
      pcall(function() ac.sendChatMessage(msg) end)
      relayChatLog(msg)
      return
    end
    if data:sub(1, 6) == 'stick:' then
      local url = data:sub(7)
      if url == '' then return end
      ownMsg(nil, url)
      local idx = PICIDX[url]
      if idx then pcall(function() ac.sendChatMessage('$STICK:' .. idx) end) end
      relayChatLog('[Sticker/GIF]')
      return
    end
    if data:sub(1, 6) == 'admin:' then
      local txt = data:sub(7)
      if txt ~= '' then sendAdminMsg(txt) end
      return
    end
    if data:sub(1, 5) == 'like:' then
      local target = data:sub(6)
      if target ~= '' then sendLike(target) end
      return
    end
    if data:sub(1, 5) == 'desc:' then
      local txt = data:sub(6)
      sendDescription(txt)
      return
    end
    -- ===== أوامر الكلانات =====
    if data:sub(1, 9) == 'clanmine:' then clanFetchMine(); return end
    -- ═══════════ [3-CHAT] شات الكلان + الشات الخاص ═══════════
    if data:sub(1, 9) == 'clansend:' then clanSendChat(data:sub(10), nil); return end
    if data:sub(1, 14) == 'clansendstick:' then clanSendChat(nil, data:sub(15)); return end
    if data == 'clanchatpoll:' then pollMessages(); return end
    if data:sub(1, 7) == 'dmsend:' then
      local okp, obj = pcall(function() return JSON.parse(data:sub(8)) end)
      if okp and obj and obj.withName and obj.text then dmSend(obj.withName, obj.text, nil) end
      return
    end
    if data:sub(1, 12) == 'dmsendstick:' then
      local okp, obj = pcall(function() return JSON.parse(data:sub(13)) end)
      if okp and obj and obj.withName and obj.sticker then dmSend(obj.withName, nil, obj.sticker) end
      return
    end
    if data:sub(1, 8) == 'dmfetch:' then
      local okp, obj = pcall(function() return JSON.parse(data:sub(9)) end)
      if okp and obj and obj.withName then
        S.activeDmWith = obj.withName
        S.dmLastId = S.dmLastId or {}
        S.dmLastId[obj.withName] = tonumber(obj.since) or 0
        pollMessages()
      end
      return
    end
    if data == 'dmlist:' then pollMessages(); return end
    if data == 'dmclose:' then S.activeDmWith = nil; return end
    if data:sub(1, 10) == 'dmrespond:' then
      local okp, obj = pcall(function() return JSON.parse(data:sub(11)) end)
      if okp and obj and obj.withName then dmRespond(obj.withName, obj.accept == true) end
      return
    end
    if data:sub(1, 12) == 'clandetails:' then clanFetchDetails(data:sub(13)); return end
    if data:sub(1, 11) == 'clanemojis:' then clanFetchEmojis(); return end
    if data:sub(1, 11) == 'clancreate:' then
      local ok, obj = pcall(function() return JSON.parse(data:sub(12)) end)
      if ok and obj then clanPost('/drive/clan/create', { clanName = obj.clanName, tag = obj.tag, color = obj.color, emojiIdx = obj.emojiIdx }, 'تم إنشاء الكلان') end
      return
    end
    if data:sub(1, 11) == 'claninvite:' then clanPost('/drive/clan/invite', { targetName = data:sub(12) }, 'تم إرسال الدعوة 📩'); return end
    if data:sub(1, 9) == 'clankick:' then clanPost('/drive/clan/kick', { targetName = data:sub(10) }, 'تم الطرد'); return end
    if data:sub(1, 13) == 'clantransfer:' then clanPost('/drive/clan/transfer', { targetName = data:sub(14) }, 'تم نقل الملكية 👑'); return end
    if data:sub(1, 12) == 'clanpromote:' then
      clanPost('/drive/clan/coleader', { targetName = data:sub(13), promote = true }, 'تمت الترقية لقائد مساعد ⬆️'); return
    end
    if data:sub(1, 11) == 'clandemote:' then
      clanPost('/drive/clan/coleader', { targetName = data:sub(12), promote = false }, 'تم التنزيل ⬇️'); return
    end
    if data:sub(1, 10) == 'clanleave:' then clanPost('/drive/clan/leave', {}, 'غادرت الكلان'); return end
    if data:sub(1, 11) == 'clandelete:' then clanPost('/drive/clan/delete', {}, 'تم حذف الكلان'); return end
    if data:sub(1, 12) == 'clanrespond:' then
      local ok, obj = pcall(function() return JSON.parse(data:sub(13)) end)
      if ok and obj then clanPost('/drive/clan/respond', { clanId = obj.clanId, accept = obj.accept and true or false }, obj.accept and 'انضممت للكلان ✅' or 'تم الرفض') end
      return
    end
    if data:sub(1, 9) == 'clanedit:' then
      local ok, obj = pcall(function() return JSON.parse(data:sub(10)) end)
      if ok and obj then clanPost('/drive/clan/edit', { desc = obj.desc, color = obj.color, emojiIdx = obj.emojiIdx }, 'تم الحفظ') end
      return
    end
    if data:sub(1, 6) == 'notif:' then cStor.dc_notif = (data:sub(7) == '1'); return end
    if data:sub(1, 5) == 'opac:' then cStor.dc_opacity = (tonumber(data:sub(6)) or 100) / 100; return end
    if data == 'close' then closeChat(); return end
  end

  -- كل أمر من الصفحة يجي بصيغة "<رقم>:<الأمر>" وعلى أكثر من قناة (sendAsync + عنوان الصفحة)
  -- ندمجها هنا مع منع التكرار — نفس الرقم ينفذ مرة وحدة فقط مهما تكرر وصوله
  local function handleRaw(payload)
    if type(payload) ~= 'string' or payload == '' then return end
    local seq, cmd = payload:match('^(%d+):(.*)$')
    if seq then
      if S.seen[seq] then return end
      S.seen[seq] = S.clock
      for k, t in pairs(S.seen) do if S.clock - t > 30 then S.seen[k] = nil end end
      handleData(cmd)
    else
      handleData(payload)   -- توافق مع أوامر بدون رقم
    end
  end
  local function handleTitle(t)
    if type(t) ~= 'string' then return end
    if t == 'DRIVECHAT:ready' then markReady(); return end
    local payload = t:match('^DRIVECHAT:(.+)$')
    if payload then handleRaw(payload) end
  end

  -- ===== إنشاء المتصفح =====
  -- نفس نمط IDDL بالضبط: حجم ثابت (CHAT_W×CHAT_H) لا يتغيّر أبداً — بدون تحجيم، فقط سحب/تحريك.
  -- هذا يتجنّب كل مشاكل تحجيم متصفح CSP (فقدان رسائل، عدم استجابة، إعادة تحميل).
  -- CSP 0.3.0 غيّر طبقة الويب (CEF)؛ نحمّل المتصفح بأمان — لو فشل ما ينهار السكربت كله
  -- نجرّب أكثر من مسار للموديول (تحسّباً لتغيّر المسار في 0.3.0)
  local WebBrowser = nil
  do
    local paths = { 'shared/web/browser', 'shared/webbrowser', 'shared/web/webview', 'web/browser' }
    for _, p in ipairs(paths) do
      local ok, mod = pcall(require, p)
      if ok and type(mod) ~= 'nil' then
        WebBrowser = mod
        ac.log('[DRIVE CHAT] WebBrowser loaded from: ' .. p)
        break
      end
    end
    if not WebBrowser then
      ac.log('[DRIVE CHAT] WebBrowser require FAILED on all paths (CSP 0.3.0?) — chat browser disabled')
    end
  end
  -- ننشئ المتصفح مرة وحدة بحجم ثابت (نفس نمط IDDL بالحرف — pcall واحد، بدون رجوع/إعادة بناء)
  if WebBrowser then
    pcall(function()
      S.browser = WebBrowser({ size = vec2(CHAT_W, CHAT_H), backgroundColor = rgbm(0, 0, 0, 0) })
      S.lastNav = 0
      S.browser:navigate(CHAT_URL)
      S.browser:onReceive('Drivechat', function(self, data)
        if type(data) == 'string' then handleRaw(data) end
      end)
      S.browser:onTitleChange(function(self, title) handleTitle(title) end)
    end)
  end

  -- ===== إخفاء شات CSP المدمج (نفس طريقة IDDL بالحرف) =====
  -- نستبدل رسم شات CSP برسمة فاضية شفافة بالكامل + نبلع الإدخال
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
    end, function()
      return true
    end)
  end)

  -- ===== اعتراض رسائل AC =====
  ac.onChatMessage(function(message, sender)
    local msg = tostring(message)
    if msg:find("not an administrator") or msg:find("Unrecognized command") then return true end
    if msg:find("^SYNTAX ERROR:") or msg:find("SYNTAX ERROR: Use '") then return true end
    -- كتم ماركرات بروتوكول بلقنات DRIVE (ترافيك/شدّة/رادار)
    if msg:find("^!TFC_") or msg:find("^!TRAFFIC") or msg:find("^!SHADDA") or msg:find("^!RADAR") then return true end
    if msg:find("Slot %[") or msg:find("is not configured") then return true end   -- سبام إعدادات السيرفر
    if sender == 0 then return true end   -- صدى رسالتك — الصفحة عرضتها من قبل
    local sidx = msg:match("^%$STICK:(%d+)$")
    if sidx then
      local url = ALLPICS[tonumber(sidx)]
      if url then
        local ssrv = not sender or sender < 0
        local snm = ssrv and "السيرفر" or (ac.getDriverName(sender) or ("لاعب " .. tostring(sender)))
        local rr = S.ranks[snm]
        local m = { name = snm, sticker = url, srv = ssrv, mine = false, t = S.clock,
          avatar = (rr and rr.avatar) or nil }
        pushLog(m); toBrowser(m)
      end
      return true
    end
    local srv = not sender or sender < 0
    local nm = srv and "السيرفر" or (ac.getDriverName(sender) or ("لاعب " .. tostring(sender)))
    -- تعريب رسائل السيرفر الشائعة
    if srv then
      local carN, drv = msg:match("^Car (%d+) is now driven by (.+)$")
      if carN then msg = "السيارة " .. carN .. " صار يقودها " .. drv
      elseif msg:find("shutting down", 1, true) then msg = "⚠️ السيرفر يسوي ريستارت — نرجع خلال ثواني، أعد الدخول 🔄"
      elseif msg:find("You have been kicked", 1, true) then msg = "تم طردك من السيرفر"
      elseif msg:find("You have been banned", 1, true) then msg = "تم حظرك من السيرفر"
      end
    end
    local rr = S.ranks[nm]
    local m = { name = nm, text = msg, srv = srv, mine = false, t = S.clock,
      avatar = (rr and rr.avatar) or nil }
    pushLog(m); toBrowser(m)
    return true
  end)

  pushLog({ name = "DRIVE", text = "مرحباً بك في سيرفر DRIVE! · اضغط C لإظهار/إخفاء الشات 🧡", srv = true, t = 0 })
  for _, rx in ipairs({ "onnected", "joined the server", "left the server", "has left" }) do
    pcall(function() ac.blockSystemMessages(rx) end)
  end

  -- ===== فقاعات الإشعارات (Native — لما الشات مقفول) =====
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
  local AVR = 20
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
  -- هل هذا الاسم حساب مربوط؟ (له بيانات ديسكورد في الرتب)
  local function isLinked(name)
    if not name or name == "" then return false end
    local r = S.ranks[name]
    return r ~= nil and r.discord ~= nil and r.discord ~= false
  end
  local function bubbleInner(m, areaW)
    if m.sticker then return 96, 96 end
    local maxInner = math.floor((areaW - AVR * 2 - 44) * 0.94)
    local nat = ui.measureDWriteText(m.text or "", 15, 4000)
    local innerW = math.max(30, math.min(maxInner, math.ceil(nat.x) + 2))
    local wr = ui.measureDWriteText(m.text or "", 15, innerW)
    return innerW, math.max(18, math.ceil(wr.y))
  end
  local function msgRowH(m, areaW)
    local _, contentH = bubbleInner(m, areaW)
    return 24 + (contentH + 16) + 14
  end
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
      ui.drawRectFilled(vec2(bx2 - 3, bubY + 4), vec2(bx2, bubY + bubH - 4), rgbm(ACC.r, ACC.g, ACC.b, 0.95 * a), 2)
    else
      drawAvatar(x + AVR + 2, avcy, AVR, m)
      local nameX = x + AVR * 2 + 12
      dwLeft2(dispName, 14, nameX, yy, 240, 18, nameCol)
      -- شارة "حساب مربوط" بجانب اسم المرسِل (يشوفها الآخرون)
      if not m.srv and isLinked(m.name) then
        local nmW = math.min(240, math.ceil(ui.measureDWriteText(dispName, 14, 400).x) + 4)
        local bx = nameX + nmW + 5
        ui.drawRectFilled(vec2(bx, yy + 2), vec2(bx + 15, yy + 16), rgbm(0.13, 0.6, 0.4, 0.9 * a), 4)
        ui.setCursor(vec2(bx, yy + 1)); ui.dwriteTextAligned("✓", 11, ui.Alignment.Center, ui.Alignment.Center, vec2(15, 15), false, rgbm(1, 1, 1, a))
      end
      bx1 = nameX; bx2 = bx1 + bubW
      ui.drawRectFilled(vec2(bx1, bubY), vec2(bx2, bubY + bubH), m.srv and rgbm(0.11, 0.115, 0.14, 0.96 * a) or rgbm(0.17, 0.17, 0.19, 0.96 * a), 12)
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
    if not cStor.dc_notif then return end   -- إشعارات الفقاعات معطّلة من زر 🔔
    if S.open then return end
    local recent = {}
    for i = #S.log, math.max(1, #S.log - 12), -1 do
      local lm = S.log[i]
      -- تخطّى رسائلي أنا (المرسِل ما يشوف فقاعة رسالته)، واعرض فقط آخر 16 ثانية
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

  local function inRect2(p, a, b)
    return p.x >= a.x and p.y >= a.y and p.x <= b.x and p.y <= b.y
  end

  -- ===== الرسم الرئيسي =====
  local function draw()
    local sim = ac.getSim()
    if not sim then return end
    local now = S.clock

    -- قراءة عنوان الصفحة كل فريم — قناة أوامر احتياطية (الصفحة تكتب الأوامر بالعنوان)
    if S.browser then
      pcall(function() handleTitle(S.browser:title() or '') end)
    end

    -- إخفاء شات AC الأصلي (نفس طريقة IDDL): نلقى نافذته ونخفيها ونصغّرها ونطلعها برا الشاشة
    -- ويعاد التطبيق كل ٥ ثواني عشان لو اللعبة رجعتها
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

    -- لو الصفحة جهزت وما وصلنا تأكيد إن sendAsync توصلها — نتحول تلقائياً لوضع الطوارئ
    if S.browser and S.ready and S.initSent and not S.acked and not S.jsMode and (now - S.readyAt) > 3 then
      S.jsMode = true
      S.initSent = false   -- نعيد دفع كل شي بالقناة الجديدة
      ac.log('DriveChat: sendAsync not acked - switching to javascript-url mode')
    end

    -- إعادة المحاولة لين الصفحة تجهز (navigate كل 5 ثواني)
    if S.browser and not S.ready then
      if not S.ready and (now - S.lastNav) > 5 then
        S.navRetries = S.navRetries + 1
        S.lastNav = now
        pcall(function() S.browser:navigate(CHAT_URL .. '?r=' .. S.navRetries) end)
      end
    end

    -- نبض: لو الصفحة جهزت وبعدين وقفت ترد — أعد التحميل
    if S.browser and S.ready and (not S.jsMode) and S.lastOk > 0 and (now - S.lastOk) > 60 then
      S.ready = false; S.initSent = false; S.lastNav = now; S.lastOk = 0
      pcall(function() S.browser:navigate(CHAT_URL .. '?hb=' .. tostring(math.floor(now))) end)
    end

    -- دفعة أولية للصفحة (مرة واحدة بعد كل ready)
    if S.browser and S.ready and not S.initSent then
      S.initSent = true
      jsend('dcInit', {
        me = myName(),
        notifs = cStor.dc_notif and 1 or 0,
        opacity = math.floor((cStor.dc_opacity or 1) * 100),
        adminEnabled = (ADMIN_WEBHOOK ~= "") and 1 or 0,
      })
      jsend('dcStickers', STICKERS)
      jsend('dcGifs', GIFS)
      -- مزامنة الرسائل السابقة
      for _, m in ipairs(S.log) do toBrowser(m) end
    end

    -- الرتب / الربط من البوت (كل 30 ثانية)
    if RANKS_URL ~= "" and (now - S.lastRanks) > 10 then
      S.lastRanks = now
      fetchRanks()
    end

    -- [3-CHAT] شات الكلان + قائمة المحادثات الخاصة + المحادثة المفتوحة (كل 4 ثواني)
    if RANKS_URL ~= "" and (now - S.lastMsgPoll) > 4 then
      S.lastMsgPoll = now
      pollMessages()
    end

    -- دفع قائمة الأعضاء + بياناتهم الحية (كل ثانية)
    if S.browser and S.ready and (now - S.lastPush) > 1 then
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
              -- لاعب جديد دخل: نجدّد الرتب قريباً عشان تبان بياناته بسرعة (بدل انتظار 30ث)
              if now - (S.lastRanks or 0) > 3 then S.lastRanks = now - 10 end
            end
            seen[jk] = true
            local r = S.ranks[nm]
            local d = 0
            if my and i ~= 0 then d = (car.position - my.position):length() end
            local carName = ''
            pcall(function() carName = ac.getCarName(i) or '' end)
            list[#list + 1] = {
              name = nm, isMe = (i == 0), status = 'on',
              rank = rankOf(nm),
              rankColor = (r and r.color) or false,
              discord = (r and r.discord) or false,
              avatar = (r and r.avatar) or nil,
              car = carName,
              dur = math.floor(now - S.joined[jk]),
              dist = math.floor(d),
              speed = math.floor(car.speedKmh or 0),
              level = (r and r.level) or 0,                       -- لفل اللعب
              levelTitle = (r and r.levelTitle) or false,         -- مسمّى اللفل
              totalMinutes = (r and r.totalMinutes) or 0,         -- إجمالي دقايق الجلوس
              firstSeen = (r and r.firstSeen) or false,           -- أول دخول (ms)
              desc = (r and r.desc) or false,                     -- وصف البروفايل
              likes = (r and r.likes) or 0,                       -- عدد اللايكات
              clan = (r and r.clan) or false,                     -- اسم الكلان
              clanTag = (r and r.clanTag) or false,               -- تاق الكلان
              clanColor = (r and r.clanColor) or false,           -- لون الكلان
              clanEmoji = (r and r.clanEmoji) or false,           -- إيموجي الكلان
            }
          end
        end
        for k in pairs(S.joined) do if not seen[k] then S.joined[k] = nil end end
        jsend('dcMembers', list, function() S.lastOk = S.clock end)
      end)
    end

    -- فقاعات الإشعارات (الشات مقفول)
    pcall(function() drawChatLog(sim) end)

    -- نافذة الشات (الشات مفتوح)
    if S.open and not S.browser then S.open = false; S.wantsKbd = false end
    if S.open and S.browser then
      if not S.pos then
        if cStor.dc_posX >= 0 and cStor.dc_posY >= 0 then
          S.pos = vec2(cStor.dc_posX, cStor.dc_posY)
        else
          S.pos = vec2((sim.windowWidth - S.W) * 0.5, (sim.windowHeight - S.H) * 0.5)
        end
      end
      S.pos.x = math.max(-S.W + 80, math.min(S.pos.x, sim.windowWidth - 80))
      S.pos.y = math.max(0, math.min(S.pos.y, sim.windowHeight - 60))

      -- ===== سحب فقط (بدون تحجيم) — نفس نمط IDDL بالحرف: حجم ثابت، الهيدر يسحب =====
      local cmp = ui.mousePos()
      local clp = cmp - S.pos
      local cClicked = ui.mouseClicked(ui.MouseButton.Left)
      -- منطقة السحب من الهيدر (أعلى 60px — ما عدا يسار 300px عشان أزرار التحكم RTL)
      if cClicked and not S.dragging and not S.overlayOpen and inRect2(clp, vec2(300, 0), vec2(S.W, 60)) then
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

      ui.transparentWindow('driveChatBrowser', S.pos, vec2(S.W, S.H), true, true, function()
        S.browser:draw(vec2(0, 0), vec2(S.W, S.H), true)
        if not S.dragging then
          local uis = ac.getUI()
          local mlp = ui.mouseLocalPos()
          S.browser:mouseInput(vec2(mlp.x / S.W, mlp.y / S.H),
            { uis.isMouseLeftKeyDown, uis.isMouseRightKeyDown, uis.isMouseMiddleKeyDown }, uis.mouseWheel)
          S.browser:focus(true)
          ui.setMouseCursor(S.browser:mouseCursor())

          local kb = ui.captureKeyboard(true, true)
          if kb then S.browser:keyboard(kb) end
        end
      end)

      -- كليك برا النافذة = قفل (ما نقفل وقت السحب)
      if cClicked and not S.dragging and not inRect2(clp, vec2(0, 0), vec2(S.W, S.H)) then
        closeChat()
      end
      -- Escape = قفل
      if ac.isKeyDown(ui.KeyIndex.Escape) then closeChat() end
    end
  end

  -- ===== الواجهة العامة =====
  return {
    update = function(dt)
      S.clock = S.clock + dt
      -- زر C يفتح الشات فقط — الإغلاق: ESC أو ✕ أو كليك برا النافذة
      -- (عشان كتابة حرف c أو أي حرف اختصار ما تسوي شي وأنت تكتب)
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
      chatTyping = S.open   -- أوقف مفاتيح منيو اللاعب (رجوع/بوست/شدّات) طول ما الشات مفتوح

      -- تجميد اختصارات كل السكربتات الثانية (الشدّات/الأدمن...) وقت ما الشات مفتوح:
      -- نرفع وضع الإدخال إلى UI مع حفظ/استرجاع الوضع السابق (نفس علاج كراش ReplayManager).
      -- نعيد فرضه كل فريم طول ما الشات مفتوح (مو مرة وحدة بس) — لو سكربت ثاني على
      -- السيرفر يرجّعه لوضع اللعب بالخطأ، نستعيده فوراً بدل ما يتسرب ضغط المفاتيح.
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
    end,
    draw = function()
      local ok, err = pcall(draw)
      if not ok and not S.errLogged then S.errLogged = true; ac.log("DriveChat draw error: " .. tostring(err)) end
    end,
    toggle = function()
      if S.open then closeChat() else openChat() end
    end,
    isOpen = function() return S.open end,
    -- معلومات رتبة لاعب (يستخدمها بلوك التاقات [29]): {rank, color, discord, avatar} أو nil
    getRank = function(name)
      local r = S.ranks[name]
      if r and r.rank and r.rank ~= '' then return r end
      local fr = ADMIN_NAMES[name]
      if fr then return { rank = fr } end
      return nil
    end,
    push = function(name, text, isServer)
      local m = { name = name, text = text, srv = isServer and true or false, t = S.clock }
      pushLog(m); toBrowser(m)
    end,
  }
end)
if not __dcOk then
  ac.log("DriveChat load failed: " .. tostring(DriveChat))
  DriveChat = { update = function() end, draw = function() end, isOpen = function() return false end, toggle = function() end, push = function() end, getRank = function() return nil end }
else
  ac.log("[DRIVE CHAT] v8.8 loaded OK — UI input mode reasserted every frame (keyboard leak fix)")
end

--=================================================================
-- [29] DRIVE TAGS  (أسماء اللاعبين فوق السيارات — DRIVE Community)
--   رسم مباشر على الشاشة: نسقط موقع كل سيارة بـ ac.worldCoordinateToScreen
--   ونرسم التاق فوقها — بدون ui.onDriverNameTag نهائياً (كان يبدّل الأسماء
--   بين السيارات لما يشتغل من سكربت سيرفر). الاسم والموقع يُقرآن من نفس
--   السيارة بنفس اللحظة، فتبادل الأسماء مستحيل.
--   الشكل: [علم] الاسم [بادج الرتبة بلونها من نظام /link] — هوية DRIVE.
--=================================================================
local __dtOk, DriveTags = pcall(function()
  local T = {
    ENABLED   = true,
    DISTANCE  = 150,    -- أقصى مسافة تظهر فيها التاقات (متر)
    HEIGHT    = 1.35,   -- ارتفاع التاق فوق مركز السيارة (متر)
    FONT      = "Segoe UI;Weight=Bold",
    SHOW_FLAG = true,   -- علم الدولة جنب الاسم
    MAX_SIZE  = 26,     -- حجم الخط وأنت قريب
    MIN_SIZE  = 13,     -- حجم الخط عند أبعد مسافة
  }
  local ACC2 = rgbm(1.00, 0.45, 0.06, 1)
  local RANK_COLS = {
    admin = rgbm(0.90, 0.28, 0.30, 1),
    mod   = rgbm(0.31, 0.61, 0.98, 1),
    vip   = rgbm(0.96, 0.77, 0.09, 1),
  }
  local measureCache = {}
  local function meas(txt, size)
    local k = size .. '|' .. txt
    local v = measureCache[k]
    if not v then v = ui.measureDWriteText(txt, size); measureCache[k] = v end
    return v
  end
  local function levelOf(name)
    local ok, r = pcall(function() return DriveChat.getRank(name) end)
    if not ok or not r or not r.level or r.level <= 0 then return nil end
    return r.level
  end
  -- كلان اللاعب للتاق: يرجع (tag, color) أو nil
  local function clanInfo(name)
    local ok, r = pcall(function() return DriveChat.getRank(name) end)
    if not ok or not r or not r.clanTag or r.clanTag == '' then return nil end
    local col = rgbm(0.53, 0.34, 0.83, 1)   -- بنفسجي افتراضي للكلان
    local hex = r.clanColor
    if type(hex) == 'string' and #hex >= 7 and hex:sub(1, 1) == '#' then
      col = rgbm((tonumber(hex:sub(2,3),16) or 135)/255, (tonumber(hex:sub(4,5),16) or 87)/255, (tonumber(hex:sub(6,7),16) or 212)/255, 1)
    end
    return tostring(r.clanTag), col
  end
  local function rankInfo(name)
    local ok, r = pcall(function() return DriveChat.getRank(name) end)
    if not ok or not r or not r.rank or r.rank == '' then return nil end
    local col = ACC2
    local hex = r.color
    if type(hex) == 'string' and #hex >= 7 and hex:sub(1, 1) == '#' then
      local rr = (tonumber(hex:sub(2, 3), 16) or 247) / 255
      local gg = (tonumber(hex:sub(4, 5), 16) or 130) / 255
      local bb = (tonumber(hex:sub(6, 7), 16) or 14) / 255
      col = rgbm(rr, gg, bb, 1)
    else
      col = RANK_COLS[tostring(r.rank):lower()] or ACC2
    end
    return tostring(r.rank), col
  end
  local flagCache = {}
  local function flagPath(i)
    local p = flagCache[i]
    if p ~= nil then if p ~= false then return p end return nil end
    local code = nil
    pcall(function() code = ac.getDriverNationCode(i) end)
    if code and code ~= '' then
      if code == 'PLA' then code = 'AC' end
      p = "/content/gui/NationFlags/" .. string.upper(code) .. ".png"
    else
      p = false
    end
    flagCache[i] = p
    if p ~= false then return p end
    return nil
  end
  local suppressed = false

  local function drawOneTag(car, sw, sh, camPos, camFwd)
    local nm = ac.getDriverName(car.index) or ''
    if nm == '' then return end
    local dist = car.distanceToCamera or 9999
    local maxD = tagStore.tg_distance or T.DISTANCE
    if dist <= 0.5 or dist > maxD then return end
    local wpos = car.position + vec3(0, tagStore.tg_height or T.HEIGHT, 0)
    if camPos and camFwd then
      local rel = wpos - camPos
      if rel:dot(camFwd) <= 0 then return end   -- خلف الكاميرا
    end
    local sp = nil
    pcall(function() sp = ui.projectPoint(wpos) end)   -- نفس دالة IDDL (تشتغل داخل drawUI)
    if not sp then return end
    if sp.x ~= sp.x or sp.y ~= sp.y then return end    -- NaN = خلف الكاميرا / إسقاط فاشل
    if sp.x < -500 or sp.y < -500 or sp.x > sw + 500 or sp.y > sh + 500 then return end
    local t = 1 - dist / maxD
    local alpha = math.min(1, math.max(0, t * 3.2)) * (tagStore.tg_opacity or 1)
    if alpha <= 0.03 then return end
    local size = math.floor((T.MIN_SIZE + (T.MAX_SIZE - T.MIN_SIZE) * t) * (tagStore.tg_scale or 1) + 0.5)
    local nmSz = meas(nm, size)
    local gap = math.max(5, size * 0.34)
    local fl = (T.SHOW_FLAG and tagStore.tg_flag == 1) and flagPath(car.index) or nil
    local flS = fl and (size + 4) or 0
    local rankText, rankCol = rankInfo(nm)
    local rankSize = math.max(10, math.floor(size * 0.72))
    local pillW, pillH, rkSz = 0, 0, nil
    if rankText then
      rkSz = meas(rankText, rankSize)
      pillW = rkSz.x + size * 0.7
      pillH = rkSz.y + size * 0.28
    end
    -- لفل اللعب (Lv.N) — حبّة صغيرة برتقالية بعد الرتبة
    local lvNum = levelOf(nm)
    local lvText, lvW, lvH, lvSz = nil, 0, 0, nil
    if lvNum then
      lvText = "Lv." .. lvNum
      lvSz = meas(lvText, rankSize)
      lvW = lvSz.x + size * 0.6
      lvH = rkSz and pillH or (lvSz.y + size * 0.28)
    end
    -- كلان (تاق) — حبّة بلون الكلان بعد اللفل
    local clTag, clCol = clanInfo(nm)
    local clText, clW, clH, clSz = nil, 0, 0, nil
    if clTag then
      clText = "[" .. clTag .. "]"
      clSz = meas(clText, rankSize)
      clW = clSz.x + size * 0.6
      clH = (lvH > 0) and lvH or (clSz.y + size * 0.28)
    end
    local cw = nmSz.x + (fl and (flS + gap) or 0) + (rankText and (gap + pillW) or 0) + (lvText and (gap + lvW) or 0) + (clText and (gap + clW) or 0)
    local ch = math.max(nmSz.y, flS, pillH, lvH, clH)
    local padX, padY = size * 0.45, size * 0.26
    local x0 = sp.x - (cw + padX * 2) * 0.5
    local y0 = sp.y - (ch + padY * 2)   -- الصندوق يجلس فوق نقطة الإسقاط
    local x1 = x0 + cw + padX * 2
    local y1 = y0 + ch + padY * 2
    -- صندوق DRIVE: أسود + خط برتقالي سفلي
    ui.drawRectFilled(vec2(x0, y0), vec2(x1, y1), rgbm(0.03, 0.03, 0.04, 0.90 * alpha), size * 0.38)
    ui.drawRectFilled(vec2(x0 + 6, y1 - 2.4), vec2(x1 - 6, y1), rgbm(ACC2.r, ACC2.g, ACC2.b, 0.9 * alpha), 1.5)
    local x = x0 + padX
    local yMid = (y0 + y1) * 0.5
    if fl then
      pcall(function()
        ui.drawImage(fl, vec2(x, yMid - flS * 0.5), vec2(x + flS, yMid + flS * 0.5), rgbm(1, 1, 1, alpha))
      end)
      x = x + flS + gap
    end
    ui.setCursor(vec2(x, yMid - nmSz.y * 0.5))
    ui.beginOutline()
    ui.dwriteText(nm, size, rgbm(1, 1, 1, alpha))
    ui.endOutline(rgbm(0, 0, 0, 0.9 * alpha), math.max(2, size * 0.14))
    x = x + nmSz.x
    if rankText then
      x = x + gap
      local py0 = yMid - pillH * 0.5
      ui.drawRectFilled(vec2(x, py0), vec2(x + pillW, py0 + pillH),
        rgbm(rankCol.r * 0.22, rankCol.g * 0.22, rankCol.b * 0.22, 0.95 * alpha), pillH * 0.5)
      ui.drawRect(vec2(x, py0), vec2(x + pillW, py0 + pillH),
        rgbm(rankCol.r, rankCol.g, rankCol.b, 0.9 * alpha), pillH * 0.5, nil, 1.4)
      ui.setCursor(vec2(x + (pillW - rkSz.x) * 0.5, py0 + (pillH - rkSz.y) * 0.5))
      ui.dwriteText(rankText, rankSize, rgbm(rankCol.r, rankCol.g, rankCol.b, alpha))
      x = x + pillW
    end
    if lvText then
      x = x + gap
      local ly0 = yMid - lvH * 0.5
      ui.drawRectFilled(vec2(x, ly0), vec2(x + lvW, ly0 + lvH),
        rgbm(ACC2.r * 0.22, ACC2.g * 0.22, ACC2.b * 0.22, 0.95 * alpha), lvH * 0.5)
      ui.drawRect(vec2(x, ly0), vec2(x + lvW, ly0 + lvH),
        rgbm(ACC2.r, ACC2.g, ACC2.b, 0.9 * alpha), lvH * 0.5, nil, 1.4)
      ui.setCursor(vec2(x + (lvW - lvSz.x) * 0.5, ly0 + (lvH - lvSz.y) * 0.5))
      ui.dwriteText(lvText, rankSize, rgbm(ACC2.r, ACC2.g, ACC2.b, alpha))
      x = x + lvW
    end
    if clText then
      x = x + gap
      local cy0 = yMid - clH * 0.5
      ui.drawRectFilled(vec2(x, cy0), vec2(x + clW, cy0 + clH),
        rgbm(clCol.r * 0.22, clCol.g * 0.22, clCol.b * 0.22, 0.95 * alpha), clH * 0.5)
      ui.drawRect(vec2(x, cy0), vec2(x + clW, cy0 + clH),
        rgbm(clCol.r, clCol.g, clCol.b, 0.9 * alpha), clH * 0.5, nil, 1.4)
      ui.setCursor(vec2(x + (clW - clSz.x) * 0.5, cy0 + (clH - clSz.y) * 0.5))
      ui.dwriteText(clText, rankSize, rgbm(clCol.r, clCol.g, clCol.b, alpha))
    end
  end

  return {
    update = function(dt)
      -- كتم أسماء AC الافتراضية (لو مفعلة بإعدادات اللاعب) عشان ما تطلع دبل فوق تاقاتنا
      if not suppressed then
        local s = ac.getSim()
        if s and s.driverNamesShown then
          pcall(function()
            ui.onDriverNameTag(true, rgbm(0, 0, 0, 0), function() end, { tagSize = vec2(16, 16) })
          end)
          suppressed = true
        end
      end
    end,
    draw = function()
      if not T.ENABLED then return end
      if tagStore.tg_enabled == 0 then return end
      local s = ac.getSim()
      if not s then return end
      local sw, sh = s.windowWidth, s.windowHeight
      local camPos, camFwd = nil, nil
      pcall(function() if ac.getCameraPosition then camPos = ac.getCameraPosition() end end)
      pcall(function() if ac.getCameraForward then camFwd = ac.getCameraForward() end end)
      ui.transparentWindow("driveTagsOverlay", vec2(0, 0), vec2(sw, sh), false, function()
        ui.pushDWriteFont(T.FONT)
        for i = 0, (s.carsCount or 0) - 1 do
          if i ~= s.focusedCar then
            local car = ac.getCar(i)
            local dn = ac.getDriverName(i) or ""
            if car and car.isConnected and not car.isAIControlled and not string.find(dn, "Traffic") then
              pcall(drawOneTag, car, sw, sh, camPos, camFwd)
            end
          end
        end
        ui.popDWriteFont()
      end, ui.WindowFlags.NoInputs + ui.WindowFlags.NoMouseInputs)
    end,
  }
end)
if not __dtOk then
  ac.log("DriveTags load failed: " .. tostring(DriveTags))
  DriveTags = { update = function() end, draw = function() end }
end
function script.update(dt)
  Core.update(dt)

  -- فتح/غلق القائمة
  local mk = (not isTyping()) and ui.keyboardButtonDown(CFG.MENU_TOGGLE_KEY)
  if mk and not menuPrevKey then panelOpen = not panelOpen end
  menuPrevKey = mk

  boostUpdate(dt)
  extrasUpdate()
  rewindUpdate(dt)
  shaddaUpdate(dt)

  pcall(function() DriveChat.update(dt) end)
  pcall(function() DriveTags.update(dt) end)   -- [29] تاقات الأسماء فوق السيارات
end
--=================================================================
-- [25] SCREEN HUD  (الطبقات فوق الشاشة)
--=================================================================

-- شعار "اضغط D لفتح القائمة" — يطلع فقط لما تكون القائمة مقفولة
-- ويختفي لو التطبيق نفسه مقفول من قائمة تطبيقات CSP.
local function drawOpenHint()
  if not CFG.SHOW_OPEN_HINT then return end
  if hintStor.hide_hints then return end
  if panelOpen then return end

  local screen = ac.getUI().windowSize
  -- أول ثواني بعد الدخول: تنبيه أكبر وأوضح، بعدها يرجع صغير وهادي
  local intro = Core.clock < CFG.HINT_INTRO_SEC
  local k = intro and 1.5 or 1.0
  local w, h = 300 * k, 56 * k
  local x = (screen.x - w) * 0.5
  ui.transparentWindow("driveOpenHint", vec2(x, 18), vec2(w, h), false, function()
    local pulse = 0.55 + 0.45 * math.abs(math.sin(Core.clock * 2))
    ui.drawRectFilled(vec2(0, 0), vec2(w, h), rgbm(0.035, 0.035, 0.042, intro and 0.93 or 0.88), 12 * k)
    ui.drawRect(vec2(0, 0), vec2(w, h), rgbm(ACC.r, ACC.g, ACC.b, 0.25 + 0.45 * pulse), 12 * k, nil, 1.5 * k)
    drawLogo(12 * k, 10 * k, 82 * k, h - 10 * k)
    ui.drawLine(vec2(92 * k, 12 * k), vec2(92 * k, h - 12 * k), rgbm(1, 1, 1, 0.12), 1)
    dwBox("اضغط  " .. CFG.MENU_KEY_LABEL .. "  لفتح القائمة", 16 * k,
      100 * k, 0, w - 112 * k, h, rgbm(CW.r, CW.g, CW.b, intro and 1.0 or (0.70 + 0.30 * pulse)))
  end, ui.WindowFlags.NoInputs + ui.WindowFlags.NoMouseInputs)
end

-- شعار "اضغط C لفتح الشات" — أسفل الشاشة، يظهر فقط لما يكون الشات مقفول (نفس ستايل شعار D)
local function drawChatHint()
  if not CFG.SHOW_OPEN_HINT then return end
  if hintStor.hide_hints then return end
  if DriveChat.isOpen() then return end

  local screen = ac.getUI().windowSize
  local intro = Core.clock < CFG.HINT_INTRO_SEC
  local k = intro and 1.35 or 0.92
  local w, h = 280 * k, 50 * k
  local x = (screen.x - w) * 0.5
  local y = screen.y - h - 16
  ui.transparentWindow("driveChatHint", vec2(x, y), vec2(w, h), true, true, function()
    local pulse = 0.55 + 0.45 * math.abs(math.sin(Core.clock * 2))
    -- زر شفاف يغطي التلميح كامل — الضغط عليه يفتح الشات (مثل زر C)
    local clicked = ui.invisibleButton("##chatHintBtn", vec2(w, h))
    local hover = ui.itemHovered()
    ui.drawRectFilled(vec2(0, 0), vec2(w, h), rgbm(0.035, 0.035, 0.042, intro and 0.93 or (hover and 0.95 or 0.86)), 12 * k)
    ui.drawRect(vec2(0, 0), vec2(w, h), rgbm(ACC.r, ACC.g, ACC.b, hover and 0.9 or (0.25 + 0.45 * pulse)), 12 * k, nil, 1.5 * k)
    drawLogo(12 * k, 9 * k, 74 * k, h - 9 * k)
    ui.drawLine(vec2(84 * k, 11 * k), vec2(84 * k, h - 11 * k), rgbm(1, 1, 1, 0.12), 1)
    dwBox("اضغط هنا او xC", 13.5 * k,
      92 * k, 0, w - 104 * k, h, rgbm(CW.r, CW.g, CW.b, intro and 1.0 or (0.70 + 0.30 * pulse)))
    if hover then ui.setMouseCursor(ui.MouseCursor.Hand) end
    if clicked then DriveChat.toggle() end
  end)
end

--=================================================================
-- [30] HIDE DEFAULT CAR LABELS  (إخفاء أسماء AC/CSP الافتراضية فوق السيارات)
--   نفس طريقة IDDL: ac.hideCarLabels لكل سيارة، يعاد تطبيقها كل ثانيتين
--   وعند تغير عدد السيارات — عشان تاقات DRIVE هي الوحيدة الظاهرة.
--=================================================================
local _labelHide = { last = -10, count = -1 }
function script.draw3D()
  pcall(function()
    local s = ac.getSim()
    local total = (s and s.carsCount) or 0
    if total ~= _labelHide.count or (Core.clock - _labelHide.last) > 2.0 then
      for ci = 0, total - 1 do
        ac.hideCarLabels(ci, true)
      end
      _labelHide.count = total
      _labelHide.last = Core.clock
    end
  end)
end

function script.drawUI()
  pcall(function() DriveTags.draw() end)   -- [29] التاقات (تحت كل النوافذ)
  DriveChat.draw()
  drawMenuHost()   -- [28] المضيف الدائم — المنيو يشتغل بدون تفعيل الاكسترا
  drawOpenHint()
  drawChatHint()

  -- حماية الشبح
  if Core.ghostOn then
    ui.transparentWindow("ghostHUD", vec2(10, 10), vec2(320, 50), false, function()
      ui.drawRectFilled(vec2(0, 0), vec2(320, 50), rgbm(0, 0, 0, 0.6), 8)
      ui.pushDWriteFont(FONT)
      ui.dwriteTextAligned(string.format("وضع الحماية: %.1f ثانية", Core.ghostT),
        17, ui.Alignment.Center, ui.Alignment.Center, vec2(300, 40), false, CC)
      ui.popDWriteFont()
    end)
  end

  -- الرجوع بالزمن
  if rIsRewinding then
    local ws = ac.getUI().windowSize
    ui.transparentWindow("RewindHUD", vec2(0, 0), ws, false, function()
      ui.drawRectFilled(vec2(0, 0), ws, rgbm(0, 0, 0, 0.2), 0)
      ui.pushDWriteFont(FONT)
      ui.dwriteTextAligned("REWINDING TIME...", 50, ui.Alignment.Center, ui.Alignment.Center, ws, false, ACC)
      ui.dwriteTextAligned("ارفع المفتاح للمتابعة", 22, ui.Alignment.Center, ui.Alignment.Center, ws + vec2(0, 90), false, rgbm(1, 1, 1, 0.85))
      ui.popDWriteFont()
    end, ui.WindowFlags.NoInputs + ui.WindowFlags.NoMouseInputs)
  end
end

ac.log("DRIVE Panel loaded (v8.8 — XP levels (tag + profile))")

--=================================================================
-- [27] ONLINE EXTRAS REGISTRATION (التسجيل في شريط الأونلاين)
--=================================================================

-- تسجيل القائمة الرئيسية (DRIVE Panel)
pcall(function()
    ui.registerOnlineExtra("DRIVE Panel", function()
        -- هذا الكود يتنفذ لما اللاعب يضغط على الزر في قائمة الأونلاين
        panelOpen = not panelOpen 
    end)
end)

-- تسجيل الشات (DRIVE Chat) كزر إضافي (اختياري)
pcall(function()
    ui.registerOnlineExtra("DRIVE Chat", function()
        -- يفتح ويقفل الشات عند الضغط عليه
        DriveChat.toggle()
    end)
end)
