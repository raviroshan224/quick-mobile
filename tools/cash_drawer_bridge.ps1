<#
Cash Drawer Bridge (dev/test tool only — not shipped with the app)
====================================================================

Lets you test the "Cash Drawer" feature (Settings > Hardware > Cash Drawer,
Network transport) without a real network-capable ESC/POS printer, as long
as you have *any* ESC/POS printer reachable from this PC (typically over
USB, installed as a normal Windows printer).

What it does:
  - Listens on TCP `-Port` (default 9100, the standard raw/JetDirect ESC/POS
    port) on this PC.
  - Whatever raw bytes it receives (the drawer-kick command from the app)
    get forwarded as-is to the Windows printer named `-PrinterName`, using
    a RAW datatype print job via winspool.drv (no reformatting/no print
    dialog — just the exact bytes, which is required for ESC/POS control
    sequences like the drawer kick to work).

How to use it:
  1. Plug your ESC/POS printer into this PC over USB and install it as a
     normal Windows printer (Settings > Printers & scanners). Note its
     exact Windows printer name.
  2. Find this PC's LAN IP (same WiFi/network as the test phone):
       ipconfig   (look for the IPv4 Address on your WiFi adapter)
  3. Run this script, passing your printer's exact Windows name:
       powershell -ExecutionPolicy Bypass -File tools\cash_drawer_bridge.ps1 -PrinterName "POS-80C (copy 2)"
  4. In the app: Settings > Hardware > Cash Drawer > Network > enter this
     PC's LAN IP and port 9100 > Test.

The script tries to add a Windows Firewall rule allowing inbound TCP on
`-Port` automatically (best-effort — needs an elevated/Admin PowerShell to
succeed; if it can't, allow PowerShell through Windows Defender Firewall
manually, or the phone's connection attempt will just time out).

Ctrl+C to stop.
#>

param(
    [string]$PrinterName = "POS-80C (copy 2)",
    [int]$Port = 9100
)

Add-Type -Name RawPrinterHelper -Namespace PInvoke -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
public struct DOCINFOA {
    [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
}

[DllImport("winspool.drv", EntryPoint="OpenPrinterA", SetLastError=true, CharSet=CharSet.Ansi, ExactSpelling=true)]
public static extern bool OpenPrinter(string szPrinter, out IntPtr hPrinter, IntPtr pd);

[DllImport("winspool.drv", EntryPoint="ClosePrinter", SetLastError=true, ExactSpelling=true)]
public static extern bool ClosePrinter(IntPtr hPrinter);

[DllImport("winspool.drv", EntryPoint="StartDocPrinterA", SetLastError=true, CharSet=CharSet.Ansi, ExactSpelling=true)]
public static extern bool StartDocPrinter(IntPtr hPrinter, int level, ref DOCINFOA di);

[DllImport("winspool.drv", EntryPoint="EndDocPrinter", SetLastError=true, ExactSpelling=true)]
public static extern bool EndDocPrinter(IntPtr hPrinter);

[DllImport("winspool.drv", EntryPoint="StartPagePrinter", SetLastError=true, ExactSpelling=true)]
public static extern bool StartPagePrinter(IntPtr hPrinter);

[DllImport("winspool.drv", EntryPoint="EndPagePrinter", SetLastError=true, ExactSpelling=true)]
public static extern bool EndPagePrinter(IntPtr hPrinter);

[DllImport("winspool.drv", EntryPoint="WritePrinter", SetLastError=true, ExactSpelling=true)]
public static extern bool WritePrinter(IntPtr hPrinter, byte[] pBytes, int dwCount, out int dwWritten);
'@

function Send-RawBytesToPrinter {
    param([string]$PrinterName, [byte[]]$Bytes)
    $hPrinter = [IntPtr]::Zero
    if (-not [PInvoke.RawPrinterHelper]::OpenPrinter($PrinterName, [ref]$hPrinter, [IntPtr]::Zero)) {
        throw "OpenPrinter failed for '$PrinterName' (Win32 error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
    }
    try {
        $di = New-Object PInvoke.RawPrinterHelper+DOCINFOA
        $di.pDocName = "CashDrawerBridge"
        $di.pDataType = "RAW"
        if (-not [PInvoke.RawPrinterHelper]::StartDocPrinter($hPrinter, 1, [ref]$di)) {
            throw "StartDocPrinter failed (Win32 error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
        }
        try {
            [PInvoke.RawPrinterHelper]::StartPagePrinter($hPrinter) | Out-Null
            $written = 0
            [PInvoke.RawPrinterHelper]::WritePrinter($hPrinter, $Bytes, $Bytes.Length, [ref]$written) | Out-Null
            [PInvoke.RawPrinterHelper]::EndPagePrinter($hPrinter) | Out-Null
            Write-Host "  -> wrote $written / $($Bytes.Length) bytes to Windows printer '$PrinterName'"
        } finally {
            [PInvoke.RawPrinterHelper]::EndDocPrinter($hPrinter) | Out-Null
        }
    } finally {
        [PInvoke.RawPrinterHelper]::ClosePrinter($hPrinter) | Out-Null
    }
}

try {
    New-NetFirewallRule -DisplayName "CashDrawerBridge-$Port" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -ErrorAction Stop | Out-Null
    Write-Host "Firewall rule added for inbound TCP $Port."
} catch {
    Write-Host "Could not add firewall rule automatically ($($_.Exception.Message)) - if the phone can't connect, allow PowerShell/port $Port through Windows Defender Firewall manually (run this script as Administrator to auto-add the rule)."
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
$listener.Start()
Write-Host "Bridging TCP:$Port -> Windows printer '$PrinterName'."
Write-Host "In the app: Settings > Hardware > Cash Drawer > Network, host = this PC's LAN IP, port = $Port."
Write-Host "Waiting for connections... (Ctrl+C to stop)"

while ($true) {
    $client = $listener.AcceptTcpClient()
    $remote = $client.Client.RemoteEndPoint
    Write-Host "Connection from $remote"
    try {
        $stream = $client.GetStream()
        $ms = New-Object System.IO.MemoryStream
        $buffer = New-Object byte[] 4096
        while ($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $ms.Write($buffer, 0, $read)
        }
        $bytes = $ms.ToArray()
        if ($bytes.Length -gt 0) {
            Write-Host ("  received {0} bytes: {1}" -f $bytes.Length, ([BitConverter]::ToString($bytes)))
            Send-RawBytesToPrinter -PrinterName $PrinterName -Bytes $bytes
        } else {
            Write-Host "  (no bytes received)"
        }
    } catch {
        Write-Host "  error: $_"
    } finally {
        $client.Close()
    }
}
