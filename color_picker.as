#module mod_custom_color_picker

// WinAPIの定義
#uselib "user32.dll"
    #func GetAsyncKeyState "GetAsyncKeyState" int
    #func EnableWindow "EnableWindow" int, int
    #func GetCursorPos "GetCursorPos" var
    #func GetDC "GetDC" int
    #func SetWindowLong "SetWindowLongA" int, int, int
    #func SetLayeredWindowAttributes "SetLayeredWindowAttributes" int, int, int, int
    #func ReleaseDC "ReleaseDC" int, int
    #func SetThreadDpiAwarenessContext "SetThreadDpiAwarenessContext" int
    #func SetCapture "SetCapture" int
    #func ReleaseCapture "ReleaseCapture"
    #func SetWindowDisplayAffinity "SetWindowDisplayAffinity" int, int

#uselib "gdi32.dll"
    #func GetPixel "GetPixel" int, int, int
    #func MoveToEx "MoveToEx" int, int, int, int
    #func LineTo "LineTo" int, int, int
    #func SetROP2 "SetROP2" int, int
#uselib "dwmapi.dll"
    #func DwmSetWindowAttribute "DwmSetWindowAttribute" int, int, int, int
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#define DWMWA_USE_IMMERSIVE_DARK_MODE_OLD 19
#define DWMWA_CAPTION_COLOR 35

// パレット保存用ファイル名
#define PALETTE_FILE "utils\\color_palette.json"
#define COORDS_FILE "utils\\coordinates.json" // 追加
#define PALETTE_NUM 10
#define SET_OLD 1

// ARGB(0xAABBGGRR)をAHSVに変換する
// RGB2HSV 入力(0xAABBGGRR), A(変数), H(変数), S(変数), V(変数)
#deffunc RGB2HSV int c_argb, var _resA, var _resH, var _resS, var _resV
    _r = c_argb & 0xff
    _g = (c_argb >> 8) & 0xff
    _b = (c_argb >> 16) & 0xff
    _resA = (c_argb >> 24) & 0xff

    tr = double(_r) : tg = double(_g) : tb = double(_b)
    tv = tr : if tg > tv : tv = tg
    if tb > tv : tv = tb
    tm = tr : if tg < tm : tm = tg
    if tb < tm : tm = tb

    _resV = int(tv)
    if tv > 0 {
        _resS = int(255.0 * (tv - tm) / tv)
    } else {
        _resS = 0
    }
    if tv == tm {
        _resH = 0
    } else {
        td = tv - tm
        if tv == tr { th = 32.0 * (tg - tb) / td } else : if tv == tg { th = 32.0 * (tb - tr) / td + 64.0 } else { th = 32.0 * (tr - tg) / td + 128.0 }
        if th < 0 : th += 192.0
        _resH = int(th)
    }
    return

// AHSVをARGB(0xAABBGGRR)に変換する
// HSV2RGB A, H, S, V, 結果(変数)
#deffunc HSV2RGB int _a, int _h, int _s, int _v, var _res_argb
    _hh = _h \ 192 : if _hh < 0 : _hh += 192
    _ss = limit(_s, 0, 255)
    _vv = limit(_v, 0, 255)

    _i = _hh / 32
    _f = double(_hh \ 32) / 32.0

    _vf = double(_vv)
    _sf = double(_ss) / 255.0

    _p = int(_vf * (1.0 - _sf))
    _q = int(_vf * (1.0 - _sf * _f))
    _t = int(_vf * (1.0 - _sf * (1.0 - _f)))

    switch _i
        case 0 : r = _vv : g = _t  : b = _p  : swbreak
        case 1 : r = _q  : g = _vv : b = _p  : swbreak
        case 2 : r = _p  : g = _vv : b = _t  : swbreak
        case 3 : r = _p  : g = _q  : b = _vv : swbreak
        case 4 : r = _t  : g = _p  : b = _vv : swbreak
        case 5 : r = _vv : g = _p  : b = _q  : swbreak
    swend

    _res_argb = (r & 0xff) | ((g & 0xff) << 8) | ((b & 0xff) << 16) | ((_a & 0xff) << 24)
    return

// 外部から呼び出す命令の定義
// open_custom_color_picker 変数(結果格納用), ダークモード(0/1), タイトルバーの色, フォント名, アルファ使用(0/1)
#deffunc open_custom_color_picker var result_color, int is_dark, int bar_color, str f_name, int use_alpha
    m_hwnd = ginfo_sel
    // 初期値として現在のマウス位置付近を指定
    init_wx = ginfo_wx1 + 50 : init_wy = ginfo_wy1 + 50

    // 座標ファイルの読み込み
    init_coordinates
    exist COORDS_FILE
    if strsize != -1 {
        notesel buf : noteload COORDS_FILE
        split buf, ",", coords
        if length(coords) >= 2 {
            init_wx = int(coords(0)) : init_wy = int(coords(1))
        }
    }

    // ダーク・ライトモードに応じた配色設定
    switch is_dark
        case 0 :
            cBGR = 240, 240, 240 // 背景色 (Light)
            cTXT = 0, 0, 0       // 文字色
            cBTN = 210, 210, 210 // ボタン色
            swbreak
        case 1 :
            cBGR = 30, 30, 30    // 背景色 (Dark)
            cTXT = 255, 255, 255 // 文字色
            cBTN = 60, 60, 60    // ボタン色
            swbreak
        default
            cBGR = 240, 240, 240 // 背景色 (Light)
            cTXT = 0, 0, 0       // 文字色
            cBTN = 210, 210, 210 // ボタン色
            swbreak
        swend

    init_palette_file

    // 現在の色を RGB に分解 (result_color は 0x00BBGGRR)
    oldR = result_color & 0xff
    oldG = (result_color >> 8) & 0xff
    oldB = (result_color >> 16) & 0xff
    if use_alpha {
        curA = (result_color >> 24) & 0xff
        if curA == 0 : curA = 255 // 初期値が0（または未指定）の場合は不透明(100%)にする
    } else {
        curA = 255
    }
    oldA = curA // 初期アルファ値を保存

    // RGB -> HSV 変換 (初期値を現在の色に合わせる)
    tr = double(oldR) : tg = double(oldG) : tb = double(oldB)
    tv = tr : if tg > tv : tv = tg
    if tb > tv : tv = tb
    tm = tr : if tg < tm : tm = tg
    if tb < tm : tm = tb

    curV = int(tv)
    if tv > 0 {
        curS = int(255.0 * (tv - tm) / tv)
    } else {
        curS = 0
    }
    if tv == tm {
        curH = 0
    } else {
        td = tv - tm
        if tv == tr {
            th = 32.0 * (tg - tb) / td
        } else : if tv == tg {
            th = 32.0 * (tb - tr) / td + 64.0
        } else {
            th = 32.0 * (tr - tg) / td + 128.0
        }
        if th < 0 : th += 192.0
        curH = int(th)
    }
    // 初期値を保存しておく（クリックでのリセット用）
    initH = curH : initS = curS : initV = curV

    sH = "" + curH : sS = "" + curS : sV = "" + curV
    sR = "" + oldR : sG = "" + oldG : sB = "" + oldB
    sA = "" + (curA * 100 / 255) // 内部値(0-255)を表示用(0-100%)に変換して初期化
    is_done = 0
    click_prev = 0
    dragging_part = 0 // 0:なし, 1:色相ホイール, 2:SVボックス, 3:アルファ
    cx = 160 : cy = 160
    r_out = 135 : r_in = 110
    sv_size = 120
    sv_half = sv_size / 2
    PI = 3.14159265
    ID_WINDOW = 3 // ウィンドウID (メイン側の SID_COLOR_PICKER と合わせる)
    winH = 420
    if use_alpha : winH = 480

    ID_CACHE = 51 // キャッシュ用バッファID (メイン側との競合を避けるため変更)
    ID_SV_CACHE = 52 // SVボックスキャッシュ用バッファID
    ID_PREVIEW_TEMP = 53 // プレビュー描画用一時バッファ
    ID_PICK_PREVIEW = 54 // スポイトプレビュー用ウィンドウID
    ID_CROSS_OVERLAY = 55 // 十字線オーバーレイ用ウィンドウID

    // パレットの読み込み
    load_palette palette_colors, showOld // showOld 変数で保持

    palette_y = 310 : if use_alpha : palette_y = 375
    py = palette_y + 40

    winH = 440 : if use_alpha : winH = 505
    // screen ID_WINDOW, 460, winH, 8, m_wx + 100, m_wy + 100
    screen ID_WINDOW, 460, winH, 8, init_wx, init_wy

    title "Select Color (Right-click palette to save)"
    gsel ID_WINDOW, 2 // 常に最前面に表示してメインウィンドウの背後に回るのを防ぐ
    hPicker = hwnd
    // ダークモード設定 (1=ON, 0=OFF)
    isDarkMode = int(is_dark)
    // Windows 10/11 のバージョン差異を吸収するため、属性 19 と 20 の両方を設定する
    DwmSetWindowAttribute hPicker, DWMWA_USE_IMMERSIVE_DARK_MODE_OLD, varptr(isDarkMode), 4
    DwmSetWindowAttribute hPicker, DWMWA_USE_IMMERSIVE_DARK_MODE, varptr(isDarkMode), 4

    // タイトルバーの色設定
    titleBarColor = int(bar_color)
    DwmSetWindowAttribute hPicker, DWMWA_CAPTION_COLOR, varptr(titleBarColor), 4

    // --- スポイト用ウィンドウの事前作成 (チラツキ防止) ---
    bgscr ID_PICK_PREVIEW, 80, 55, 8, -100, -100
    font f_name, 10
    gsel ID_PICK_PREVIEW, -1

    bgscr ID_CROSS_OVERLAY, ginfo_dispx, ginfo_dispy, 8, 0, 0
    SetWindowLong hwnd, -20, 0x00080000 // WS_EX_LAYERED
    // マゼンタ(0xFF00FF)を完全透明キーとして設定 (LWA_COLORKEY = 1)
    SetLayeredWindowAttributes hwnd, 0xFF00FF, 1, 2
    // キャプチャからオーバーレイを除外(WDA_EXCLUDEFROMCAPTURE = 0x11)
    SetWindowDisplayAffinity hwnd, 0x00000011
    gsel ID_CROSS_OVERLAY, -1

    gsel ID_WINDOW // 操作対象をメインウィンドウに戻す


    // --- キャッシュバッファの作成と静的パーツの描画 ---
    buffer ID_CACHE, 460, winH
    color cBGR(0), cBGR(1), cBGR(2) : boxf
    font f_name, 11 : color cTXT(0), cTXT(1), cTXT(2)
    // 入力エリアのラベル配置 (高さを等間隔に)
    pos 330, 15  : mes "Hue (0-191):"
    pos 330, 60  : mes "Sat (0-255):"
    pos 330, 105 : mes "Val (0-255):"
    pos 330, 165 : mes "Red (0-255):"
    pos 330, 210 : mes "Green (0-255):"
    pos 330, 255 : mes "Blue (0-255):"
    if use_alpha {
        pos 330, 315 : mes "Alpha (0-100%):"
        // アルファスライダーの背景（市松模様）と枠線を描画
        ax = 25 : ay = 336 : aw = 270 : ah = 14
        color 100, 100, 100 : boxf ax - 1, ay - 1, ax + aw + 1, ay + ah + 1 // 外枠
        repeat ah / 4 + 1 : sy_cnt = cnt
            repeat aw / 4 + 1 : sx_cnt = cnt
                // 4x4ピクセルの市松模様
                if (sx_cnt + sy_cnt) \ 2 == 0 : color 180, 180, 180 : else : color 255, 255, 255
                x1 = ax + sx_cnt * 4 : y1 = ay + sy_cnt * 4
                x2 = limit(x1 + 3, ax, ax + aw) : y2 = limit(y1 + 3, ay, ay + ah)
                if x1 <= ax + aw : boxf x1, y1, x2, y2
            loop
        loop

        // プレビューエリア（New/Old）の背景（市松模様）と枠線を描画
        px = 15 : pw = 60 : ph = 60
        color 100, 100, 100 : boxf px - 1, py - 1, px + pw + 1, py + ph + 1 // 外枠
        repeat ph / 4 : cy_cnt = cnt
            repeat pw / 4 : cx_cnt = cnt
                if (cx_cnt + cy_cnt) \ 2 == 0 : color 180, 180, 180 : else : color 255, 255, 255
                boxf px + cx_cnt * 4, py + cy_cnt * 4, px + cx_cnt * 4 + 3, py + cy_cnt * 4 + 3
            loop
        loop
    }

    // パレットエリアの背景と枠線
    pos 15, palette_y - 18 : font f_name, 9 : color cTXT(0), cTXT(1), cTXT(2) : mes "Palette (L:Load / R:Save)"
    repeat PALETTE_NUM
        color 100, 100, 100 : boxf 15 + cnt * 30, palette_y, 15 + cnt * 30 + 24, palette_y + 24
    loop

    // --- 色相ホイールをピクセル単位で高密度に描画 ---
    repeat r_out * 2 + 1 : vy = cnt - r_out
        repeat r_out * 2 + 1 : vx = cnt - r_out
            dsq = double(vx * vx + vy * vy)
            if (dsq >= double(r_in * r_in)) & (dsq <= double(r_out * r_out)) {
                angle = atan(double(vy), double(vx))
                if angle < 0 : angle += 2.0 * PI
                hsvcolor int(angle * 192.0 / (2.0 * PI)), 255, 255
                pset cx + vx, cy + vy
            }
        loop
    loop
    gsel ID_WINDOW // 操作対象をピッカー画面に戻す

    // --- SVボックス用キャッシュの初期化 ---
    buffer ID_SV_CACHE, sv_size, sv_size
    lastSVHue = -1
    gsel ID_WINDOW

    // アルファ描画用の一時バッファ（1x1）を初期化
    buffer ID_PREVIEW_TEMP, 1, 1
    gsel ID_WINDOW

    // 入力ボックスの配置 (HSV + RGB)
    pos 330, 32  : input sH, 100, 22, 3 : idH = stat
    pos 330, 77  : input sS, 100, 22, 3 : idS = stat
    pos 330, 122 : input sV, 100, 22, 3 : idV = stat
    pos 330, 182 : input sR, 100, 22, 3 : idR = stat
    pos 330, 227 : input sG, 100, 22, 3 : idG = stat
    pos 330, 272 : input sB, 100, 22, 3 : idB = stat
    if use_alpha : pos 330, 332 : input sA, 100, 22, 3 : idA = stat : else : idA = -1

    EnableWindow m_hwnd, 0

    repeat
        gsel ID_WINDOW // 描画先とマウス座標の基準をこのウィンドウに固定する

        // --- 1. 入力判定と変数の更新 (描画の前に処理) ---
        getkey click, 1
        getkey rclick, 2
        if ginfo_act != ID_WINDOW : click = 0 : rclick = 0
        m_changed = 0
        p_idx = -1 // パレット操作用
        if click {
            dx = mousex - cx : dy = mousey - cy
            dist = sqrt(double(dx * dx + dy * dy))

            if dragging_part == 0 {
                if dist >= double(r_in) && dist <= double(r_out) {
                    dragging_part = 1
                } else : if abs(dx) <= sv_half && abs(dy) <= sv_half {
                    dragging_part = 2
                } else : if use_alpha && mousex >= ax && mousex <= ax + aw && mousey >= ay - 5 && mousey <= ay + ah + 5 {
                    dragging_part = 3
                } else : if mousey >= palette_y && mousey <= palette_y + 24 {
                    if (mousex >= 15) & (mousex < 15 + PALETTE_NUM * 30) : p_idx = (mousex - 15) / 30
                } else : if click_prev == 0 {
                    if showOld == 1 && mousey >= py && mousey <= py + 60 && mousex >= 45 && mousex <= 75 {
                        curH = initH : curS = initS : curV = initV
                        if use_alpha : curA = oldA : sA = "" + int(curA * 100 / 255) : objprm idA, sA
                        m_changed = 1
                    }
                }
            }

            if dragging_part == 1 { // 色相ホイール
                angle = atan(double(dy), double(dx)) : if angle < 0.0 : angle += 2.0 * PI
                curH = int(angle * 192.0 / (2.0 * PI))
                m_changed = 1
            } else : if dragging_part == 2 { // SVボックス
                ldx = limit(dx, -sv_half, sv_half)
                ldy = limit(dy, -sv_half, sv_half)
                curS = (ldx + sv_half) * 255 / sv_size : curV = 255 - (ldy + sv_half) * 255 / sv_size
                m_changed = 1
            } else : if dragging_part == 3 { // アルファ
                curA = limit(mousex - ax, 0, aw) * 255 / aw
                sA = "" + int(curA * 100 / 255) : objprm idA, sA
                m_changed = 1
            }

            // パレット選択 (左クリック)
            if (p_idx != -1) & (click_prev == 0) {
                sel_color = palette_colors(p_idx)
                tr = double(sel_color & 0xff) : tg = double((sel_color >> 8) & 0xff) : tb = double((sel_color >> 16) & 0xff)
                if use_alpha {
                    curA = (sel_color >> 24) & 0xff : if curA == 0 : curA = 255
                    sA = "" + int(curA * 100 / 255) : objprm idA, sA
                }

                tv = tr : if tg > tv : tv = tg
                if tb > tv : tv = tb
                tm = tr : if tg < tm : tm = tg
                if tb < tm : tm = tb
                curV = int(tv)
                if tv > 0 { curS = int(255.0 * (tv - tm) / tv) } else { curS = 0 }
                if tv == tm { curH = 0 } else {
                    td = tv - tm
                    if tv == tr { th = 32.0 * (tg - tb) / td } else : if tv == tg { th = 32.0 * (tb - tr) / td + 64.0 } else { th = 32.0 * (tr - tg) / td + 128.0 }
                    if th < 0 : th += 192.0
                    curH = int(th)
                }
                m_changed = 1
            }
        } else : if rclick {
            // パレット保存 (右クリック)
            if rclick_prev == 0 {
                if (mousey >= palette_y) & (mousey <= palette_y + 24) {
                    if (mousex >= 15) & (mousex < 15 + PALETTE_NUM * 30) {
                        p_idx = (mousex - 15) / 30
                        hsvcolor curH, curS, curV
                        new_c = ginfo_r | (ginfo_g << 8) | (ginfo_b << 16)
                        if use_alpha : new_c = new_c | (curA << 24) : else : new_c = new_c | (255 << 24)
                        palette_colors(p_idx) = new_c
                        save_palette palette_colors
                    }
                }
            }
        } else {
            dragging_part = 0
        }
        click_prev = click
        rclick_prev = rclick

        if m_changed {
            sH = "" + curH : sS = "" + curS : sV = "" + curV : objprm idH, sH : objprm idS, sS : objprm idV, sV
            hsvcolor curH, curS, curV : sR = "" + ginfo_r : sG = "" + ginfo_g : sB = "" + ginfo_b : objprm idR, sR : objprm idG, sG : objprm idB, sB
        }

        // 現在の HSV 状態から最新の RGB 値を確定させる
        hsvcolor curH, curS, curV
        curR = ginfo_r : curG = ginfo_g : curB = ginfo_b

        // --- 2. 描画処理 ---
        redraw 0
        pos 0, 0 : gcopy ID_CACHE, 0, 0, 460, winH

        // パレットチップの描画
        repeat PALETTE_NUM
            px_chip = 15 + cnt * 30 : py_chip = palette_y
            c_chip = palette_colors(cnt)
            cr_chip = c_chip & 0xff : cg_chip = (c_chip >> 8) & 0xff : cb_chip = (c_chip >> 16) & 0xff
            ca_chip = 255 : if use_alpha : ca_chip = (c_chip >> 24) & 0xff

            // 透明度がある場合の市松模様
            if (use_alpha) & (ca_chip < 255) {
                color 180, 180, 180 : boxf px_chip + 1, py_chip + 1, px_chip + 23, py_chip + 23
                color 255, 255, 255 : boxf px_chip + 1, py_chip + 1, px_chip + 12, py_chip + 12
                boxf px_chip + 13, py_chip + 13, px_chip + 23, py_chip + 23

                gsel ID_PREVIEW_TEMP : color cr_chip, cg_chip, cb_chip : boxf 0, 0, 0, 0 : gsel ID_WINDOW
                gmode 3, , , ca_chip
                pos px_chip + 1, py_chip + 1 : celput ID_PREVIEW_TEMP, 0, 23.0, 23.0
                gmode 0
            } else {
                color cr_chip, cg_chip, cb_chip : boxf px_chip + 1, py_chip + 1, px_chip + 23, py_chip + 23
            }
        loop

        h_angle = double(curH) * 2.0 * PI / 192.0
        ix = cx + int(cos(h_angle) * (r_in + r_out) / 2)
        iy = cy + int(sin(h_angle) * (r_in + r_out) / 2)
        color 0, 0, 0 : circle ix - 6, iy - 6, ix + 6, iy + 6, 0 // 黒い外枠を追加
        color 255, 255, 255 : circle ix - 5, iy - 5, ix + 5, iy + 5, 0

    // Hue（色相）が変わった時だけSVボックスを再描画してキャッシュする
    if curH != lastSVHue {
        gsel ID_SV_CACHE
        repeat sv_size : y_cnt = cnt
            repeat sv_size : x_cnt = cnt
                hsvcolor curH, x_cnt * 255 / sv_size, 255 - (y_cnt * 255 / sv_size)
                pset x_cnt, y_cnt
            loop
        loop
        gsel ID_WINDOW // 元のウィンドウに戻す
        lastSVHue = curH
    }
    // キャッシュされたSVボックスをコピー
    pos cx - sv_half, cy - sv_half : gcopy ID_SV_CACHE, 0, 0, sv_size, sv_size

        color 255, 255, 255
        line cx - sv_half, cy - sv_half, cx + sv_half, cy - sv_half
        line cx + sv_half, cy - sv_half, cx + sv_half, cy + sv_half
        line cx + sv_half, cy + sv_half, cx - sv_half, cy + sv_half
        line cx - sv_half, cy + sv_half, cx - sv_half, cy - sv_half

        ix = cx - sv_half + (curS * sv_size / 255)
        iy = cy + sv_half - (curV * sv_size / 255)
        color 0, 0, 0 : circle ix - 5, iy - 5, ix + 5, iy + 5, 0 // 黒い外枠を追加
        color 255, 255, 255 : circle ix - 4, iy - 4, ix + 4, iy + 4, 0

        // アルファスライダーの描画
        if use_alpha {
            ax = 25 : ay = 336 : aw = 270 : ah = 14
            // 現在のRGB色を取得（グラデーション合成用）
            hsvcolor curH, curS, curV
            tr = double(ginfo_r) : tg = double(ginfo_g) : tb = double(ginfo_b)

            // 勾配の描画（市松模様と現在の色を計算して合成）
            repeat aw : dx = cnt
                al = double(dx) / double(aw) // 左から右へのアルファ率 (0.0 - 1.0)
                repeat 4 : dy = cnt // 4つのセグメントに分けて描画 (市松の模様に合わせる)
                    y0 = ay + dy * 4 : y1 = limit(y0 + 3, ay, ay + ah - 1)
                    if ((dx / 4) + dy) \ 2 == 0 : br = 180.0:bg = 180.0:bb = 180.0 : else : br = 255.0:bg = 255.0:bb = 255.0
                    // 背景色と現在の色の線形補間
                    color int(tr * al + br * (1.0 - al)), int(tg * al + bg * (1.0 - al)), int(tb * al + bb * (1.0 - al))
                    line ax + dx, y0, ax + dx, y1
                loop
            loop

            // つまみの描画 (現在のアルファ値の位置)
            tx = ax + ((curA * 100 / 255) * aw / 100)
            color 0, 0, 0 : boxf tx - 3, ay - 2, tx + 3, ay + ah + 2
            color 255, 255, 255 : boxf tx - 2, ay - 1, tx + 2, ay + ah + 1
        }

        // 3. プレビュー (New / Old 比較)
        if showOld == 1 { // showOldが1のときだけOldを描画
            if use_alpha {
                // 新しい色 (左)
                gsel ID_PREVIEW_TEMP : hsvcolor curH, curS, curV : boxf 0, 0, 1, 1 : gsel ID_WINDOW
                gmode 3, , , curA
                pos 15, py : celput ID_PREVIEW_TEMP, 0, 30.0, 60.0

                // 元の色 (右)
                gsel ID_PREVIEW_TEMP : color oldR, oldG, oldB : boxf : gsel ID_WINDOW
                gmode 3, , , oldA
                pos 45, py : celput ID_PREVIEW_TEMP, 0, 30.0, 60.0
                gmode 0
            } else {
                hsvcolor curH, curS, curV
                boxf 15, py, 45, py + 60 // 新しい色 (左)
                color oldR, oldG, oldB
                boxf 45, py, 75, py + 60 // 元の色 (右)
            }
            // 枠線とラベル
            color cTXT(0), cTXT(1), cTXT(2)
            line 15, py, 75, py : line 75, py, 75, py + 60 : line 75, py + 60, 15, py + 60 : line 15, py + 60, 15, py
            line 45, py, 45, py + 60 // 中央の境界線
            font f_name, 9 : pos 15, py - 14 : mes "New" : pos 48, py - 14 : mes "Old"
        } else {
            // Oldを表示しない場合、Newを大きく描画するなど調整可能
            hsvcolor curH, curS, curV
            if use_alpha {
                // 修正: 一時バッファに色を描画し、アルファ値を適用して描画する
                gsel ID_PREVIEW_TEMP : color curR, curG, curB : boxf 0, 0, 0, 0 : gsel ID_WINDOW
                gmode 3, , , curA
                pos 15, py : celput ID_PREVIEW_TEMP, 0, 60.0, 60.0
                gmode 0
            } else {
                color curR, curG, curB
                boxf 15, py, 75, py + 60
            }
            color cTXT(0), cTXT(1), cTXT(2)
            line 15, py, 75, py : line 75, py, 75, py + 60 : line 75, py + 60, 15, py + 60 : line 15, py + 60, 15, py
            font f_name, 9 : pos 15, py - 14 : mes "Color"
        }

        // 数字以外の入力をフィルタリング
        s_w = sH : gosub *filter_num : if stat { sH = s_r : objprm idH, sH }
        s_w = sS : gosub *filter_num : if stat { sS = s_r : objprm idS, sS }
        s_w = sV : gosub *filter_num : if stat { sV = s_r : objprm idV, sV }
        s_w = sR : gosub *filter_num : if stat { sR = s_r : objprm idR, sR }
        s_w = sG : gosub *filter_num : if stat { sG = s_r : objprm idG, sG }
        s_w = sB : gosub *filter_num : if stat { sB = s_r : objprm idB, sB }
        if use_alpha : s_w = sA : gosub *filter_num : if stat { sA = s_r : objprm idA, sA }

        stick keys

        // 各入力ボックスの値を取得
        valH = limit(int(sH), 0, 191) : valS = limit(int(sS), 0, 255) : valV = limit(int(sV), 0, 255)
        valR = limit(int(sR), 0, 255) : valG = limit(int(sG), 0, 255) : valB = limit(int(sB), 0, 255)
        if use_alpha : valA = limit(int(sA), 0, 100) * 255 / 100 : else : valA = 255 ; 0-100%入力から0-255に変換

        // ドラッグ操作中ではない時のみ、テキスト入力ボックスの変更を反映する
        if dragging_part == 0 {
            // HSVボックスが編集された場合
            if (valH != curH) | (valS != curS) | (valV != curV) {
                curH = valH : curS = valS : curV = valV
                hsvcolor curH, curS, curV : sR = "" + ginfo_r : sG = "" + ginfo_g : sB = "" + ginfo_b : objprm idR, sR : objprm idG, sG : objprm idB, sB
            }
            // RGBボックスが編集された場合
            if (valR != curR) | (valG != curG) | (valB != curB) {
                tr = double(valR) : tg = double(valG) : tb = double(valB)
                tv = tr : if tg > tv : tv = tg
                if tb > tv : tv = tb
                tm = tr : if tg < tm : tm = tg
                if tb < tm : tm = tb
                curV = int(tv)
                if tv > 0 { curS = int(255.0 * (tv - tm) / tv) } else { curS = 0 }
                if tv == tm {
                    curH = 0
                } else {
                    td = tv - tm
                    if tv == tr {
                        th = 32.0 * (tg - tb) / td
                    } else : if tv == tg {
                        th = 32.0 * (tb - tr) / td + 64.0
                    } else {
                        th = 32.0 * (tr - tg) / td + 128.0
                    }
                    if th < 0 : th += 192.0
                    curH = int(th)
                }
                sH = "" + curH : sS = "" + curS : sV = "" + curV : objprm idH, sH : objprm idS, sS : objprm idV, sV
            }
            // Alphaボックスが編集された場合
            if (use_alpha && valA != curA) {
                curA = valA
            }
        }

        font f_name, 13 : color cBTN(0), cBTN(1), cBTN(2)
        boxf 90, py, 195, py + 60 : color cTXT(0), cTXT(1), cTXT(2) : pos 125, py + 22 : mes "OK"
        font f_name, 13 : color cBTN(0), cBTN(1), cBTN(2)
        boxf 205, py, 310, py + 60 : color cTXT(0), cTXT(1), cTXT(2) : pos 235, py + 22 : mes "Cancel"

        font f_name, 13 : color cBTN(0), cBTN(1), cBTN(2)
        boxf 320, py, 445, py + 60 : color cTXT(0), cTXT(1), cTXT(2) : pos 365, py + 22 : mes "Pick"

        if (ginfo_act == ID_WINDOW) && click && click_prev_btn == 0 {
            if mousey >= py && mousey <= py + 60 {
                // OK
                if mousex >= 90 && mousex <= 195 {
                    hsvcolor curH, curS, curV
                    result_color = ginfo_r | (ginfo_g << 8) | (ginfo_b << 16)
                    if use_alpha : result_color = result_color | (curA << 24) : else : result_color = result_color | (255 << 24)
                    is_done = 1
                }
                // Cancel
                if mousex >= 205 && mousex <= 310 {
                    // 座標を保存してからアプリを終了
                    s_coords = "" + ginfo_wx1 + "," + ginfo_wy1
                    notesel s_coords : notesave COORDS_FILE
                    end
                }
                // Pick (スポイト)
                if mousex >= 320 && mousex <= 445 {
                    gsel ID_WINDOW, -1 // ウィンドウを一時隠す

                    // 1. Pickボタンが確実に離されるのを待つ (チャタリング・長押し対策)
                    repeat
                        getkey k, 1 : if k == 0 : break
                        await 16
                    loop
                    await 150 // ボタンを離した後に少し猶予を設ける (重要)

                    // 事前に作成済みのウィンドウを表示状態にする
                    gsel ID_PICK_PREVIEW, 2
                    // 座標指定付きで表示
                    gsel ID_CROSS_OVERLAY, 2
                    SetCapture hwnd // 追加 マウス入力をこのウィンドウに固定（念のため）
                    // オーバーレイウィンドウを画面サイズ(論理サイズ)にリサイズ
                    width ginfo_dispx, ginfo_dispy, 0, 0

                    hdc_screen = GetDC(0)
                    repeat
                        // HSP標準の論理座標を取得
                        mx = ginfo_mx : my = ginfo_my

                        // 1. 十字線の描画 (オーバーレイウィンドウ - 論理座標)
                        gsel ID_CROSS_OVERLAY
                        redraw 0
                        color 255, 0, 255 : boxf // 透過色でクリア
                        color 255, 255, 255      // 十字線の色（白）
                        // 中心を数ピクセル空けて描画（取得色への干渉防止と視認性向上）
                        line 0, my, mx - 4, my
                        line mx + 4, my, ginfo_dispx, my
                        line mx, 0, mx, my - 4
                        line mx, my + 4, mx, ginfo_dispy
                        redraw 1

                        // 2. 現在の座標の色を取得 (一時的にマルチモニターDPI物理座標モードにして取得)
                        old_dpi_ctx = SetThreadDpiAwarenessContext(-4)
                        dim p_pos, 2 : GetCursorPos p_pos
                        mx_phy = p_pos(0) : my_phy = p_pos(1)
                        p_color = GetPixel(hdc_screen, mx_phy, my_phy)
                        SetThreadDpiAwarenessContext old_dpi_ctx

                        pr = p_color & 0xff : pg = (p_color >> 8) & 0xff : pb = (p_color >> 16) & 0xff

                        // プレビュー窓の更新
                        gsel ID_PICK_PREVIEW
                        color pr, pg, pb : boxf
                        color 0, 0, 0 : line 0, 0, 79, 0 : line 79, 0, 79, 54 : line 79, 54, 0, 54 : line 0, 54, 0, 0

                        // 背景の明るさに応じて文字色を白か黒に切り替える (YIQ輝度判定)
                        if (pr * 299 + pg * 587 + pb * 114) / 1000 < 128 : color 255, 255, 255 : else : color 0, 0, 0
                        pos 5, 4  : mes "R: " + pr
                        pos 5, 19 : mes "G: " + pg
                        pos 5, 34 : mes "B: " + pb

                        // マウスの右下に追従させる (論理座標)
                        width 80, 55, mx + 15, my + 15

                        getkey ek, 27
                        if ek : break // Escキーが押されたらキャンセルして戻る

                        getkey k, 1
                        if k {
                            // クリックされた瞬間の色を確定させる
                            // COLORREF (0x00BBGGRR) を分解
                            tr = double(pr)
                            tg = double(pg)
                            tb = double(pb)

                            // RGB -> HSV 変換
                            tv = tr : if tg > tv : tv = tg
                            if tb > tv : tv = tb
                            tm = tr : if tg < tm : tm = tg
                            if tb < tm : tm = tb
                            curV = int(tv)
                            if tv > 0 { curS = int(255.0 * (tv - tm) / tv) } else { curS = 0 }
                            if tv == tm { curH = 0 } else {
                                td = tv - tm
                                if tv == tr { th = 32.0 * (tg - tb) / td } else : if tv == tg { th = 32.0 * (tb - tr) / td + 64.0 } else { th = 32.0 * (tr - tg) / td + 128.0 }
                                if th < 0 : th += 192.0
                                curH = int(th)
                            }
                            // UIの入力ボックスに即座に反映 (操作対象をメインウィンドウに戻す)
                            gsel ID_WINDOW
                            sH = "" + curH : sS = "" + curS : sV = "" + curV : objprm idH, sH : objprm idS, sS : objprm idV, sV
                            hsvcolor curH, curS, curV : sR = "" + ginfo_r : sG = "" + ginfo_g : sB = "" + ginfo_b : objprm idR, sR : objprm idG, sG : objprm idB, sB
                            if use_alpha : sA = "" + int(curA * 100 / 255) : objprm idA, sA

                            // 内部状態を強制更新
                            lastSVHue = -1 // SVボックスのキャッシュを無効化して再描画させる
                            break
                        }
                        await 16
                    loop
                    ReleaseCapture // 追加 キャプチャ解除
                    ReleaseDC 0, hdc_screen
                    // High-DPI: Restore original DPI context
                    SetThreadDpiAwarenessContext old_dpi_ctx
                    gsel ID_CROSS_OVERLAY, -1 // 十字線を消す
                    gsel ID_PICK_PREVIEW, -1 // プレビュー窓を隠す

                    // 3. 決定時のクリックやEscキーが離されるのを待つ（誤動作防止）
                    repeat : getkey k, 1 : getkey ek, 27 : if (k == 0) && (ek == 0) : break : await 16 : loop

                    // 状態を完全にリセットしてからウィンドウを出す
                    click = 0 : click_prev = 0 : click_prev_btn = 1
                    gsel ID_WINDOW, 2 // ウィンドウを再表示

                    continue // メインループの先頭に戻り、今回のクリック処理を終了させる
                }
            }
        }

        // ツールチップの表示 (パレットのホバー判定)
        h_tip_idx = -1
        if (mousey >= palette_y) & (mousey <= palette_y + 24) {
            if (mousex >= 15) & (mousex < 15 + PALETTE_NUM * 30) {
                if (mousex - 15) \ 30 < 24 { // チップ間の隙間を除外
                    h_tip_idx = (mousex - 15) / 30
                }
            }
        }
        if h_tip_idx != -1 {
            c_tip = palette_colors(h_tip_idx)
            tr_tip = c_tip & 0xff
            tg_tip = (c_tip >> 8) & 0xff
            tb_tip = (c_tip >> 16) & 0xff
            ta_tip = (c_tip >> 24) & 0xff

            if use_alpha {
                // アルファ有効時は ARGB で表示
                s_tip = strf("#%02X%02X%02X%02X", ta_tip, tr_tip, tg_tip, tb_tip)
            } else {
                // アルファ無効時は RGB で表示
                s_tip = strf("#%02X%02X%02X", tr_tip, tg_tip, tb_tip)
            }
            font f_name, 9
            tw_tip = 60 : if use_alpha : tw_tip = 75
            th_tip = 15
            tx_tip = mousex + 10 : if tx_tip + tw_tip > 450 : tx_tip = mousex - tw_tip - 10
            ty_tip = mousey + 20 : if ty_tip + th_tip > winH - 10 : ty_tip = mousey - th_tip - 10

            // 背景色をチップの色に合わせ、輝度に応じて文字色を黒か白に自動選択する
            color 0, 0, 0 : boxf tx_tip, ty_tip, tx_tip + tw_tip, ty_tip + th_tip // 外枠
            color tr_tip, tg_tip, tb_tip : boxf tx_tip + 1, ty_tip + 1, tx_tip + tw_tip - 1, ty_tip + th_tip - 1
            if (tr_tip * 299 + tg_tip * 587 + tb_tip * 114) / 1000 < 128 : color 255, 255, 255 : else : color 0, 0, 0
            pos tx_tip + 4, ty_tip + 1 : mes s_tip
        }

        click_prev_btn = click
        if ginfo_act != ID_WINDOW && keys & 128 : is_done = 1
        redraw 1 : await 16 : if is_done : break
    loop

    // 終了時に現在のウィンドウ位置を保存
    // ginfo_wx1 は現在のウィンドウの左上座標を取得します
    s_coords = "" + ginfo_wx1 + "," + ginfo_wy1
    notesel s_coords : notesave COORDS_FILE


    EnableWindow m_hwnd, 1 : gsel ID_WINDOW, -1 : gsel m_hwnd
    return

*filter_num
    s_r = "" : f_count = 0
    repeat strlen(s_w)
        c_tmp = peek(s_w, cnt)
        if (c_tmp >= 48) & (c_tmp <= 57) { // '0'-'9'
            s_r += strf("%c", c_tmp)
        } else { f_count++ }
    loop
    return f_count > 0

// パレットの保存処理
#deffunc local save_palette array colors, int show_old
    s = "{\"palette\":["
    repeat PALETTE_NUM
        s += "" + colors(cnt)
        if cnt < PALETTE_NUM - 1 : s += ","
    loop
    s += "],\"old\":" + show_old + "}"
    notesel s : notesave PALETTE_FILE
    return

// パレットの読み込み処理
#deffunc local load_palette array colors, var show_old
    dim colors, PALETTE_NUM
    show_old = 1
    init_palette_file

    s = "" : notesel s : noteload PALETTE_FILE

    // JSONからパレット部分の文字列を抽出
    p1 = instr(s, 0, "\"palette\":[")
    if p1 != -1 {
        p1 += 11 // "palette":[ の長さ分進める
        p2 = instr(s, p1, "]")
        content = strmid(s, p1, p2)

        // カンマで分割
        split content, ",", s_colors
        repeat PALETTE_NUM
            if cnt < stat {
                // 文字列から数値へ変換
                colors(cnt) = int(s_colors(cnt))
            } else {
                colors(cnt) = 0
            }
        loop
    }

    // "old" 項目の抽出
    o_idx = instr(s, 0, "\"old\":")
    if o_idx != -1 {
        show_old = int(strmid(s, o_idx + 6, 1))
    }
    return

#deffunc local init_palette_file
    exist PALETTE_FILE
    if strsize != -1 : return // すでに存在する場合は何もしない

    // ディレクトリ確認・作成
    dirlist s_chk, "utils", 5
    if stat == 0 : mkdir "utils"

// すべて黒(0)で初期化
    json_data = "{\"palette\":[0,0,0,0,0,0,0,0,0,0],\"old\":" + SET_OLD + "}"
    notesel json_data
    notesave PALETTE_FILE
    return

#deffunc local init_coordinates
    exist COORDS_FILE
    if strsize != -1 : return // すでに存在する場合は何もしない

    // ディレクトリ確認・作成
    dirlist s_chk, "utils", 5
    if stat == 0 : mkdir "utils"

    // 初期座標(デフォルト値)を書き込み
    s_coords = "100,100"
    notesel s_coords : notesave COORDS_FILE
    return

#global
