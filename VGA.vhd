library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity VGA is
    generic(
        -- 800x600@60Hz SVGA 參數 (40 MHz pixel clock)
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
        i_clk    : in  std_logic;  -- 100 MHz System Clock
        i_rst    : in  std_logic;  -- Active-High Reset (Button)
        
        -- Ping Pong Game Inputs
        i_btL    : in  STD_LOGIC;  -- Left Player Button
        i_btR    : in  STD_LOGIC;  -- Right Player Button
        i_swL    : in  STD_LOGIC;  -- Left Player Switch
        i_swR    : in  STD_LOGIC;  -- Right Player Switch
        
        -- VGA Outputs
        o_red    : out std_logic_vector(3 downto 0);
        o_green  : out std_logic_vector(3 downto 0);
        o_blue   : out std_logic_vector(3 downto 0);
        o_h_sync : out std_logic;
        o_v_sync : out std_logic
    );
end VGA;

architecture rtl of VGA is

    -- 引用 pingpong 元件
    component pingpong is
        Port (
            i_clk : in STD_LOGIC;
            i_rst : in STD_LOGIC;  -- active-low
            i_btL : in STD_LOGIC;
            i_btR : in STD_LOGIC;
            i_swL : in STD_LOGIC;
            i_swR : in STD_LOGIC;
            o_led : out STD_LOGIC_VECTOR (7 downto 0)
        );
    end component;

    -- VGA Timing Constants
    constant H_TOTAL : integer := H_RES + H_FP + H_SYNC + H_BP;
    constant V_TOTAL : integer := V_RES + V_FP + V_SYNC + V_BP;

    -- Counters
    signal h_count : integer range 0 to H_TOTAL - 1 := 0;
    signal v_count : integer range 0 to V_TOTAL - 1 := 0;

    -- Pixel Clock Generation (100MHz -> 40MHz)
    signal pix_ce     : std_logic := '0';
    signal ce_idle    : integer range 0 to 3 := 0;
    signal ce_toggle  : std_logic := '0';

    -- Ping Pong Interface Signals
    signal pp_rst_n   : std_logic;              -- Active-low reset for pingpong
    signal led_status : std_logic_vector(7 downto 0); -- Output from pingpong
    
    -- Visual Design Constants (8 "LEDs" on screen)
    constant LED_Y      : integer := 300;       -- Y center position
    constant LED_RADIUS : integer := 30;        -- Radius of the LED circle
    constant LED_GAP    : integer := 90;        -- Horizontal spacing between centers
    constant LED_START_X: integer := 85;        -- X position of the first (left-most) LED
    
begin

    -- Reset Logic: Assuming i_rst is Active-High (1=Reset), 
    -- but pingpong expects Active-Low (0=Reset).
    pp_rst_n <= not i_rst;

    -- 實例化 Ping Pong 遊戲核心
    inst_pingpong: pingpong
    port map (
        i_clk => i_clk,
        i_rst => pp_rst_n, -- Convert to active-low
        i_btL => i_btL,
        i_btR => i_btR,
        i_swL => i_swL,
        i_swR => i_swR,
        o_led => led_status
    );

    ------------------------------------------------------------------------
    -- 1. Pixel Clock Enable Generator (100 MHz -> 40 MHz)
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
                        ce_idle   <= 1;       
                        ce_toggle <= '1';
                    else
                        ce_idle   <= 2;       
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
    -- 2. Horizontal Counter
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
    -- 3. Vertical Counter
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
    -- 4. Sync Signals
    ------------------------------------------------------------------------
    o_h_sync <= H_POL when (h_count >= (H_RES + H_FP) and h_count < (H_RES + H_FP + H_SYNC)) else not H_POL;
    o_v_sync <= V_POL when (v_count >= (V_RES + V_FP) and v_count < (V_RES + V_FP + V_SYNC)) else not V_POL;

    ------------------------------------------------------------------------
    -- 5. RGB Output Logic (Draw 8 Circles based on led_status)
    ------------------------------------------------------------------------
    process(i_clk)
        variable dx, dy     : integer;
        variable dist2      : integer;
        variable rad2       : integer := LED_RADIUS * LED_RADIUS;
        
        variable center_x   : integer;
        variable led_idx    : integer; -- 0 to 7
        variable is_led_on  : boolean;
        variable hit_circle : boolean;
        variable current_bit: std_logic;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                o_red   <= (others => '0');
                o_green <= (others => '0');
                o_blue  <= (others => '0');
            elsif pix_ce = '1' then
                -- 預設背景色 (深藍色)
                o_red   <= "0000";
                o_green <= "0000";
                o_blue  <= "0010"; 

                if (h_count < H_RES) and (v_count < V_RES) then
                    hit_circle := false;
                    is_led_on  := false;
                    
                    -- 優化：先檢查 Y 軸是否在圓形範圍內，減少計算量
                    if abs(v_count - LED_Y) <= LED_RADIUS then
                        
                        -- 檢查 8 個 LED 的位置
                        -- 我們假設 LED 從左到右 對應 led_status(7) 到 led_status(0)
                        for k in 0 to 7 loop
                            center_x := LED_START_X + k * LED_GAP;
                            
                            -- 檢查 X 軸範圍 (BBox check)
                            if abs(h_count - center_x) <= LED_RADIUS then
                                dx := h_count - center_x;
                                dy := v_count - LED_Y;
                                dist2 := dx*dx + dy*dy;
                                
                                if dist2 <= rad2 then
                                    hit_circle := true;
                                    
                                    -- 對應 logic vector: 螢幕左邊(k=0)對應 Bit 7
                                    current_bit := led_status(7 - k);
                                    
                                    if current_bit = '1' then
                                        is_led_on := true;
                                    else
                                        is_led_on := false;
                                    end if;
                                    
                                    -- 找到一個圓就不用繼續檢查其他的了 (因為圓不重疊)
                                    exit; 
                                end if;
                            end if;
                        end loop;
                        
                        if hit_circle then
                            if is_led_on then
                                -- 亮燈顏色 (亮黃色/紅色)
                                o_red   <= "1111";
                                o_green <= "1111";
                                o_blue  <= "0000";
                            else
                                -- 滅燈顏色 (暗灰色框線或填充)
                                o_red   <= "0010";
                                o_green <= "0010";
                                o_blue  <= "0010";
                            end if;
                        end if;
                    end if; -- Y check
                else
                    -- Blanking Interval (黑畫面)
                    o_red   <= (others => '0');
                    o_green <= (others => '0');
                    o_blue  <= (others => '0');
                end if;
            end if;
        end if;
    end process;

end rtl;

