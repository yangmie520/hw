library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity VGA is
    generic(
        -- 800x600@60Hz SVGA 標準時序（像素時鐘 40 MHz，HS/VS 為正極性）
        H_RES   : integer   := 800;
        H_FP    : integer   := 40;
        H_SYNC  : integer   := 128;
        H_BP    : integer   := 88;
        H_POL   : std_logic := '1';

        V_RES   : integer   := 600;
        V_FP    : integer   := 1;
        V_SYNC  : integer   := 4;
        V_BP    : integer   := 23;
        V_POL   : std_logic := '1'
    );
    port (
        i_clk    : in  std_logic;  -- 100 MHz 系統時鐘
        i_rst    : in  std_logic;  -- 同步清零，高有效
        o_red    : out std_logic_vector(3 downto 0);
        o_green  : out std_logic_vector(3 downto 0);
        o_blue   : out std_logic_vector(3 downto 0);
        o_h_sync : out std_logic;  -- 行同步（極性由 H_POL 決定）
        o_v_sync : out std_logic   -- 場同步（極性由 V_POL 決定）
    );
end VGA;

architecture rtl of VGA is
    constant H_TOTAL : integer := H_RES + H_FP + H_SYNC + H_BP;
    constant V_TOTAL : integer := V_RES + V_FP + V_SYNC + V_BP;

    -- 水平/垂直計數
    signal h_count : integer range 0 to H_TOTAL - 1 := 0;
    signal v_count : integer range 0 to V_TOTAL - 1 := 0;

    -- 以 100 MHz 生成平均 40 MHz 的像素節拍 clock-enable（2/3 交替）
    signal pix_ce     : std_logic := '0';
    signal ce_idle    : integer range 0 to 3 := 0;  -- 尚需等待的空轉週期數
    signal ce_toggle  : std_logic := '0';           -- 交替 2、3 週期（實際空轉 1 或 2）

    -- Mickey 三圓的幾何參數
    constant CX      : integer := H_RES/2;          -- 主圓中心 X
    constant CY      : integer := V_RES/2 + 20;     -- 主圓中心 Y（略微下移）
    constant HEAD_R  : integer := 120;              -- 主圓半徑
    constant EAR_R   : integer := 60;               -- 耳朵半徑
    constant EAR_OFF : integer := HEAD_R - EAR_R/2; -- 耳朵中心相對主圓位移

    -- 房子參數（位於右下角）
    constant HOUSE_X0 : integer := 520;  -- 主屋體左上角 X
    constant HOUSE_Y0 : integer := 360;  -- 主屋體左上角 Y
    constant HOUSE_W  : integer := 200;  -- 主屋體寬
    constant HOUSE_H  : integer := 140;  -- 主屋體高

    -- 屋頂為等腰三角形，頂點在屋體正上方中央
    constant ROOF_H   : integer := 80;   -- 屋頂高度
    constant ROOF_X0  : integer := HOUSE_X0;                 -- 屋頂底邊左端
    constant ROOF_X1  : integer := HOUSE_X0 + HOUSE_W;       -- 屋頂底邊右端
    constant ROOF_YB  : integer := HOUSE_Y0;                 -- 屋頂底邊 Y（即主屋體上緣）
    constant ROOF_XC  : integer := HOUSE_X0 + HOUSE_W/2;     -- 屋頂頂點 X
    constant ROOF_YT  : integer := HOUSE_Y0 - ROOF_H;        -- 屋頂頂點 Y

    -- 窗與門
    constant DOOR_W   : integer := 36;
    constant DOOR_H   : integer := 70;
    constant DOOR_X0  : integer := HOUSE_X0 + HOUSE_W/6;     -- 門左上角 X（偏左）
    constant DOOR_Y0  : integer := HOUSE_Y0 + HOUSE_H - DOOR_H; -- 門左上角 Y（貼近底）

    constant WIN_W    : integer := 50;
    constant WIN_H    : integer := 50;
    constant WIN_X0   : integer := HOUSE_X0 + (2*HOUSE_W)/3 - WIN_W/2; -- 窗左上角 X（偏右）
    constant WIN_Y0   : integer := HOUSE_Y0 + HOUSE_H/3;                -- 窗左上角 Y（較高）

begin
    ------------------------------------------------------------------------
    -- 以 clock-enable 產生像素節拍（平均 40 MHz）
    ------------------------------------------------------------------------
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                pix_ce    <= '0';
                ce_idle   <= 0;
                ce_toggle <= '0';
            else
                if ce_idle = 0 then
                    pix_ce <= '1';
                    if ce_toggle = '0' then
                        ce_idle   <= 1;       -- 空轉 1 週期 -> 2 週期/脈衝
                        ce_toggle <= '1';
                    else
                        ce_idle   <= 2;       -- 空轉 2 週期 -> 3 週期/脈衝
                        ce_toggle <= '0';
                    end if;
                else
                    pix_ce  <= '0';
                    ce_idle <= ce_idle - 1;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- 水平計數器
    ------------------------------------------------------------------------
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                h_count <= 0;
            elsif pix_ce = '1' then
                if h_count < H_TOTAL - 1 then
                    h_count <= h_count + 1;
                else
                    h_count <= 0;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- 垂直計數器
    ------------------------------------------------------------------------
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                v_count <= 0;
            elsif pix_ce = '1' then
                if h_count = H_TOTAL - 1 then
                    if v_count < V_TOTAL - 1 then
                        v_count <= v_count + 1;
                    else
                        v_count <= 0;
                    end if;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- 同步訊號產生
    ------------------------------------------------------------------------
    o_h_sync <= H_POL when (h_count >= (H_RES + H_FP) and h_count < (H_RES + H_FP + H_SYNC)) else not H_POL;
    o_v_sync <= V_POL when (v_count >= (V_RES + V_FP) and v_count < (V_RES + V_FP + V_SYNC)) else not V_POL;

    ------------------------------------------------------------------------
    -- RGB 繪製：米奇 + 房子
    ------------------------------------------------------------------------
    process(i_clk)
        variable dx, dy : integer;
        variable dist2  : integer;
        variable head2  : integer := HEAD_R * HEAD_R;
        variable ear2   : integer := EAR_R * EAR_R;
        variable in_head, in_ear_l, in_ear_r : boolean;
        variable L_CX, L_CY, R_CX, R_CY      : integer;

        -- 房子形狀判斷
        variable in_body : boolean;
        variable in_door : boolean;
        variable in_win  : boolean;
        variable in_roof : boolean;

        -- 屋頂三角形內點測試（使用重心坐標/半平面測試）
        -- 對於點 P=(x,y)，在三角形 (A=頂點, B=左底, C=右底) 內的條件：
        -- 1) P 在 AB、AC 的下方（因屋頂朝上），且在 BC 上方
        -- 以有向面積或半平面測試避免乘法溢出，這裡用整數乘法。
        variable x, y : integer;
        variable v0x, v0y, v1x, v1y, v2x, v2y : integer;
        variable dot00, dot01, dot02, dot11, dot12 : integer;
        variable denom, u_num, v_num : integer;
        variable u, v : integer;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                o_red   <= (others => '0');
                o_green <= (others => '0');
                o_blue  <= (others => '0');
            elsif pix_ce = '1' then
                if (h_count < H_RES) and (v_count < V_RES) then
                    -- Mickey 三圓中心
                    L_CX := CX - EAR_OFF;  L_CY := CY - EAR_OFF;
                    R_CX := CX + EAR_OFF;  R_CY := CY - EAR_OFF;

                    -- 主圓
                    dx := h_count - CX; dy := v_count - CY;
                    dist2 := dx*dx + dy*dy;
                    in_head := (dist2 <= head2);

                    -- 左耳
                    dx := h_count - L_CX; dy := v_count - L_CY;
                    dist2 := dx*dx + dy*dy;
                    in_ear_l := (dist2 <= ear2);

                    -- 右耳
                    dx := h_count - R_CX; dy := v_count - R_CY;
                    dist2 := dx*dx + dy*dy;
                    in_ear_r := (dist2 <= ear2);

                    -- 房子主屋體（矩形）
                    in_body := (h_count >= HOUSE_X0) and (h_count < HOUSE_X0 + HOUSE_W) and
                               (v_count >= HOUSE_Y0) and (v_count < HOUSE_Y0 + HOUSE_H);

                    -- 房子門（矩形）
                    in_door := (h_count >= DOOR_X0) and (h_count < DOOR_X0 + DOOR_W) and
                               (v_count >= DOOR_Y0) and (v_count < DOOR_Y0 + DOOR_H);

                    -- 房子窗（矩形，含十字框）
                    in_win  := (h_count >= WIN_X0) and (h_count < WIN_X0 + WIN_W) and
                               (v_count >= WIN_Y0) and (v_count < WIN_Y0 + WIN_H);

                    -- 屋頂三角形（A=頂點, B=左底角, C=右底角）
                    -- 使用重心坐標測試：u>=0, v>=0, u+v<=1
                    x := h_count; y := v_count;
                    v0x := ROOF_XC - ROOF_X0; v0y := ROOF_YT - ROOF_YB;  -- B->A
                    v1x := ROOF_X1 - ROOF_X0; v1y := 0;                 -- B->C
                    v2x := x - ROOF_X0;       v2y := y - ROOF_YB;       -- B->P

                    dot00 := v0x*v0x + v0y*v0y;
                    dot01 := v0x*v1x + v0y*v1y;
                    dot02 := v0x*v2x + v0y*v2y;
                    dot11 := v1x*v1x + v1y*v1y;
                    dot12 := v1x*v2x + v1y*v2y;

                    denom := dot00*dot11 - dot01*dot01;
                    if denom /= 0 then
                        -- 計算 u, v 的分子（不做除法，直接用不等式判斷）
                        u_num := dot11*dot02 - dot01*dot12;
                        v_num := dot00*dot12 - dot01*dot02;
                        -- 在三角形內若：u>=0 且 v>=0 且 u+v<=denom
                        in_roof := (u_num >= 0) and (v_num >= 0) and ((u_num + v_num) <= denom);
                    else
                        in_roof := false;
                    end if;

                    -- 組合顏色：
                    -- Mickey：白色
                    -- 房子主體：淡灰
                    -- 屋頂：紅色
                    -- 門：深棕（紅+綠少量）
                    -- 窗：亮青（綠+藍）
                    -- 窗格線：黑色細框（靠邊界判斷）
                    if in_head or in_ear_l or in_ear_r then
                        o_red   <= "1111";
                        o_green <= "1111";
                        o_blue  <= "1111";
                    elsif in_roof then
                        o_red   <= "1111";
                        o_green <= "0010";
                        o_blue  <= "0010";
                    elsif in_body then
                        -- 邊框加深：靠近矩形邊緣 2 像素描邊
                        if (h_count - HOUSE_X0 < 2) or ((HOUSE_X0 + HOUSE_W - 1 - h_count) < 2) or
                           (v_count - HOUSE_Y0 < 2) or ((HOUSE_Y0 + HOUSE_H - 1 - v_count) < 2) then
                            o_red   <= "0110";
                            o_green <= "0110";
                            o_blue  <= "0110";
                        else
                            o_red   <= "1010";
                            o_green <= "1010";
                            o_blue  <= "1010";
                        end if;
                    elsif in_door then
                        o_red   <= "1000";
                        o_green <= "0100";
                        o_blue  <= "0010";
                    elsif in_win then
                        -- 先畫窗格線：外框及中線 1~2 像素
                        if ( (h_count - WIN_X0 < 2) or ((WIN_X0 + WIN_W - 1 - h_count) < 2) or
                             (v_count - WIN_Y0 < 2) or ((WIN_Y0 + WIN_H - 1 - v_count) < 2) or
                             (abs(h_count - (WIN_X0 + WIN_W/2)) < 1) or
                             (abs(v_count - (WIN_Y0 + WIN_H/2)) < 1) ) then
                            o_red   <= "0000";
                            o_green <= "0000";
                            o_blue  <= "0000";
                        else
                            o_red   <= "0000";
                            o_green <= "1111";
                            o_blue  <= "1111";
                        end if;
                    else
                        o_red   <= (others => '0');
                        o_green <= (others => '0');
                        o_blue  <= (others => '0');
                    end if;
                else
                    -- 消隱/同步期間輸出黑色
                    o_red   <= (others => '0');
                    o_green <= (others => '0');
                    o_blue  <= (others => '0');
                end if;
            end if;
        end if;
    end process;

end rtl;

















