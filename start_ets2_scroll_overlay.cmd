@echo off
setlocal
set "ETS2_SCROLL_OVERLAY_SELF=%~f0"
set "ETS2_SCROLL_OVERLAY_COMPILEONLY="
if /I "%~1"=="-CompileOnly" set "ETS2_SCROLL_OVERLAY_COMPILEONLY=1"
if /I "%~1"=="/CompileOnly" set "ETS2_SCROLL_OVERLAY_COMPILEONLY=1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -Command "$ErrorActionPreference = 'Stop'; $self = $env:ETS2_SCROLL_OVERLAY_SELF; $content = [System.IO.File]::ReadAllText($self); $marker = '# POWERSHELL_PAYLOAD'; $idx = $content.LastIndexOf($marker); if ($idx -lt 0) { throw 'Embedded PowerShell payload marker not found.' }; $payload = $content.Substring($idx + $marker.Length); $script = [scriptblock]::Create($payload); if ($env:ETS2_SCROLL_OVERLAY_COMPILEONLY) { & $script -CompileOnly } else { & $script }"
exit /b %ERRORLEVEL%

# POWERSHELL_PAYLOAD
param(
    [switch]$CompileOnly
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$source = @"
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Text;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public sealed class Ets2ScrollOverlay : Form
{
    private const int StepPercent = 3;
    private const int WH_MOUSE_LL = 14;
    private const int WM_MOUSEWHEEL = 0x020A;
    private const int WHEEL_DELTA = 120;
    private const int VK_RBUTTON = 0x02;
    private const int VK_MBUTTON = 0x04;
    private const int VK_CONTROL = 0x11;
    private const int VK_MENU = 0x12;
    private const int VK_Q = 0x51;
    private const int WS_EX_TRANSPARENT = 0x20;
    private const int WS_EX_TOOLWINDOW = 0x80;
    private const int WS_EX_NOACTIVATE = 0x08000000;

    private readonly LowLevelMouseProc mouseProc;
    private readonly Timer timer;
    private readonly Font statusFont;
    private IntPtr mouseHook = IntPtr.Zero;
    private int scrollValue = 0;
    private string statusText = "Neutral 0%";
    private Color statusColor = Color.Gainsboro;

    public Ets2ScrollOverlay()
    {
        mouseProc = MouseHookCallback;

        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        Size = new Size(260, 48);
        BackColor = Color.Fuchsia;
        TransparencyKey = Color.Fuchsia;
        Opacity = 1.0;
        TopMost = true;
        ShowInTaskbar = false;
        DoubleBuffered = true;
        Padding = new Padding(0);

        statusFont = new Font("Segoe UI", 16.0f, FontStyle.Bold, GraphicsUnit.Point);

        timer = new Timer();
        timer.Interval = 100;
        timer.Tick += TimerTick;

        UpdateDisplay();
    }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
            return cp;
        }
    }

    protected override bool ShowWithoutActivation
    {
        get { return true; }
    }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);

        MoveToTopOfActiveScreen();

        mouseHook = SetHook(mouseProc);
        if (mouseHook == IntPtr.Zero)
        {
            MessageBox.Show("Could not start the ETS2 mouse hook.", "ETS2 Scroll Overlay",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            Close();
            return;
        }

        Visible = IsEts2Foreground();
        timer.Start();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        timer.Stop();
        if (mouseHook != IntPtr.Zero)
        {
            UnhookWindowsHookEx(mouseHook);
            mouseHook = IntPtr.Zero;
        }
        base.OnFormClosing(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);

        e.Graphics.Clear(Color.Fuchsia);
        e.Graphics.TextRenderingHint = TextRenderingHint.SingleBitPerPixelGridFit;

        using (SolidBrush brush = new SolidBrush(statusColor))
        using (StringFormat format = new StringFormat())
        {
            format.Alignment = StringAlignment.Center;
            format.LineAlignment = StringAlignment.Near;
            format.FormatFlags = StringFormatFlags.NoClip;
            e.Graphics.DrawString(statusText, statusFont, brush, ClientRectangle, format);
        }
    }

    private void TimerTick(object sender, EventArgs e)
    {
        if (IsKeyDown(VK_CONTROL) && IsKeyDown(VK_MENU) && IsKeyDown(VK_Q))
        {
            Close();
            return;
        }

        if (IsResetPressed())
        {
            ResetScrollValue();
        }

        bool ets2Active = IsEts2Foreground();
        if (Visible != ets2Active)
        {
            Visible = ets2Active;
        }
        if (ets2Active)
        {
            MoveToTopOfActiveScreen();
        }
    }

    private IntPtr MouseHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0 && wParam.ToInt32() == WM_MOUSEWHEEL && IsEts2Foreground() && !IsKeyDown(VK_RBUTTON) && !IsResetPressed())
        {
            MSLLHOOKSTRUCT mouseInfo = (MSLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(MSLLHOOKSTRUCT));
            int delta = (short)((mouseInfo.mouseData >> 16) & 0xffff);
            int wheelSteps = Math.Sign(delta);

            if (wheelSteps != 0)
            {
                scrollValue = Clamp(scrollValue + (wheelSteps * StepPercent), -100, 100);
                BeginInvoke((Action)UpdateDisplay);
            }
        }

        return CallNextHookEx(mouseHook, nCode, wParam, lParam);
    }

    private void UpdateDisplay()
    {
        if (scrollValue > 0)
        {
            statusText = "Throttle " + CurvedPercentText(scrollValue) + "%";
            statusColor = Color.LimeGreen;
        }
        else if (scrollValue < 0)
        {
            statusText = "Brake " + CurvedPercentText(scrollValue) + "%";
            statusColor = Color.OrangeRed;
        }
        else
        {
            statusText = "Neutral 0%";
            statusColor = Color.Gainsboro;
        }

        Invalidate();
    }

    private void ResetScrollValue()
    {
        if (scrollValue == 0) return;

        scrollValue = 0;
        UpdateDisplay();
    }

    private static string CurvedPercentText(int value)
    {
        int absoluteValue = Math.Abs(value);
        if (absoluteValue == 0) return "0";

        double curved = Math.Pow(absoluteValue / 100.0, 2.0) * 100.0;
        return curved.ToString("0.##", CultureInfo.InvariantCulture);
    }

    private static bool IsResetPressed()
    {
        return IsEts2Foreground() && IsKeyDown(VK_MENU) && IsKeyDown(VK_MBUTTON);
    }

    private void MoveToTopOfActiveScreen()
    {
        IntPtr hwnd = GetForegroundWindow();
        Screen screen = hwnd == IntPtr.Zero ? Screen.PrimaryScreen : Screen.FromHandle(hwnd);
        Rectangle area = screen.Bounds;
        Location = new Point(area.Left + ((area.Width - Width) / 2), area.Top);
    }

    private static int Clamp(int value, int min, int max)
    {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }

    private static bool IsEts2Foreground()
    {
        IntPtr hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return false;

        uint processId;
        GetWindowThreadProcessId(hwnd, out processId);
        if (processId == 0) return false;

        try
        {
            using (Process process = Process.GetProcessById((int)processId))
            {
                return String.Equals(process.ProcessName, "eurotrucks2", StringComparison.OrdinalIgnoreCase);
            }
        }
        catch
        {
            return false;
        }
    }

    private static bool IsKeyDown(int virtualKey)
    {
        return (GetAsyncKeyState(virtualKey) & unchecked((short)0x8000)) != 0;
    }

    private static IntPtr SetHook(LowLevelMouseProc proc)
    {
        using (Process currentProcess = Process.GetCurrentProcess())
        using (ProcessModule currentModule = currentProcess.MainModule)
        {
            return SetWindowsHookEx(WH_MOUSE_LL, proc, GetModuleHandle(currentModule.ModuleName), 0);
        }
    }

    private delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int x;
        public int y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSLLHOOKSTRUCT
    {
        public POINT pt;
        public uint mouseData;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelMouseProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Windows.Forms", "System.Drawing"

if ($CompileOnly) {
    Write-Host "ETS2 scroll overlay compiled successfully."
    return
}

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
[System.Windows.Forms.Application]::Run([Ets2ScrollOverlay]::new())
