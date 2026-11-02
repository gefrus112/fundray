// ============================================================================
// FundrayMain.cs — Fundray Windows Enhancement Toolkit (GUI skeleton)
// https://github.com/gefrus112/fundray
//
// IMPORTANT: Fundray is NOT an operating system. It is an enhancement toolkit
// that runs on top of Windows 7 SP1 / 10 / 11 and tunes the existing install.
//
// Target: .NET Framework 4.8 (WinForms), Windows 7 SP1 compatible.
// The source is intentionally kept at C# 5 language level so it can be
// compiled by the in-box compiler (csc.exe v4.0.30319) without Visual Studio.
//
// Design rules honored here:
//   * A system restore point is offered before any optimization runs.
//   * The GUI only orchestrates readable PowerShell scripts — no hidden magic.
//   * Every action is echoed into the on-screen log and a log file.
//   * The Windows 11 tab is a visible "in development" placeholder: nothing
//     Windows 11-specific is applied or shipped yet.
// ============================================================================

using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Security.Principal;
using System.Text;
using System.Windows.Forms;

namespace Fundray
{
    // ------------------------------------------------------------------ //
    //  Entry point
    // ------------------------------------------------------------------ //
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new FundrayMainForm());
        }
    }

    // ------------------------------------------------------------------ //
    //  Main window
    // ------------------------------------------------------------------ //
    internal sealed class FundrayMainForm : Form
    {
        private const string AppVersion = "0.1.0";
        private const string RepoUrl = "https://github.com/gefrus112/fundray";
        private const string SiteUrl = "https://gefrus112.github.io/fundray/";

        private readonly TabControl tabs = new TabControl();
        private readonly TextBox logBox = new TextBox();
        private readonly System.Collections.Generic.List<Button> busyButtons =
            new System.Collections.Generic.List<Button>();
        private bool busy;

        // Performance tab checkboxes (each maps to a switch in optimize.ps1)
        private CheckBox chkPowerPlan;
        private CheckBox chkStartup;
        private CheckBox chkServices;
        private CheckBox chkTemp;
        private CheckBox chkVisuals;
        private CheckBox chkKeepEffects;

        public FundrayMainForm()
        {
            BuildUi();
            CheckAdministrator();
            AppendLog("Fundray " + AppVersion + " started. Fundray is an enhancement toolkit, not an operating system.");
        }

        // ---------------------------------------------------------------- //
        //  UI construction
        // ---------------------------------------------------------------- //
        private void BuildUi()
        {
            Text = "Fundray - Windows Enhancement Toolkit (not an operating system)";
            Size = new Size(880, 660);
            MinimumSize = new Size(780, 580);
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Segoe UI", 9F);

            logBox.Multiline = true;
            logBox.ReadOnly = true;
            logBox.ScrollBars = ScrollBars.Vertical;
            logBox.Dock = DockStyle.Bottom;
            logBox.Height = 150;
            logBox.BackColor = Color.FromArgb(24, 26, 33);
            logBox.ForeColor = Color.FromArgb(220, 224, 232);
            logBox.Font = new Font("Consolas", 8.75F);

            tabs.Dock = DockStyle.Fill;

            tabs.TabPages.Add(BuildOverviewTab());
            tabs.TabPages.Add(BuildPerformanceTab());
            tabs.TabPages.Add(BuildTerminalTab());
            tabs.TabPages.Add(BuildAppearanceTab());
            tabs.TabPages.Add(BuildWindows11Tab());

            // Add the Fill control first, then the docked ones (WinForms docks
            // in reverse order of the Controls collection).
            Controls.Add(tabs);
            Controls.Add(logBox);
        }

        private TabPage BuildOverviewTab()
        {
            var page = NewTab("Overview");
            var panel = NewPanel(page);

            int row = 0;
            AddTo(panel, row++, NewHeading("Fundray " + AppVersion + " - Windows Enhancement Toolkit"));
            AddTo(panel, row++, NewText(
                "Fundray is NOT an operating system. It runs on top of your existing Windows 7 SP1 / 10 / 11 " +
                "installation and tunes it: performance, Windows Terminal configuration and safe appearance " +
                "changes. Every action is executed by readable PowerShell scripts, logged, and reversible."));

            AddTo(panel, row++, NewHeading("How to use Fundray safely"));
            AddTo(panel, row++, NewText(
                "1. Create a system restore point (button on the Performance tab).\n" +
                "2. Tick only the tweaks you understand and click Apply.\n" +
                "3. If anything behaves unexpectedly, use One-click restore - or rstrui.exe for a full system restore."));

            AddTo(panel, row++, NewHeading("Links"));
            AddTo(panel, row++, NewLink("Project website (Home / Docs / Download / Windows 11)", SiteUrl));
            AddTo(panel, row++, NewLink("GitHub repository - source code, issues, releases", RepoUrl));

            return page;
        }

        private TabPage BuildPerformanceTab()
        {
            var page = NewTab("Performance");
            var panel = NewPanel(page);

            int row = 0;
            AddTo(panel, row++, NewHeading("Performance optimization"));
            AddTo(panel, row++, NewText(
                "Whitelist-based tweaks only - critical services (Defender, Windows Update, RPC, and friends) " +
                "are never touched. A restore point is checked before anything is applied."));

            chkPowerPlan = NewCheck("Switch to the High Performance / Ultimate Performance power plan", true);
            chkStartup = NewCheck("Disable whitelisted startup entries (see scripts/optimize.ps1)", false);
            chkServices = NewCheck("Disable whitelisted non-critical services (telemetry, retail demo, ...)", false);
            chkTemp = NewCheck("Clean temporary files and the Windows Update cache", true);
            chkVisuals = NewCheck("Adjust visual effects for performance", false);
            chkKeepEffects = NewCheck("Keep most visual effects (balanced mode - recommended)", true);

            AddTo(panel, row++, chkPowerPlan);
            AddTo(panel, row++, chkStartup);
            AddTo(panel, row++, chkServices);
            AddTo(panel, row++, chkTemp);
            AddTo(panel, row++, chkVisuals);
            AddTo(panel, row++, chkKeepEffects);

            var buttons = NewFlow();
            var btnRestorePoint = NewButton("Create restore point", OnCreateRestorePoint);
            var btnApply = NewButton("Apply selected optimizations", OnApplyPerformance);
            var btnRevert = NewButton("One-click restore", OnRevert);
            btnApply.BackColor = Color.FromArgb(0, 120, 212);
            btnApply.ForeColor = Color.White;
            btnApply.FlatStyle = FlatStyle.Flat;
            buttons.Controls.Add(btnRestorePoint);
            buttons.Controls.Add(btnApply);
            buttons.Controls.Add(btnRevert);
            AddTo(panel, row++, buttons);

            AddTo(panel, row++, NewText(
                "Note: Windows allows creating one restore point per 24 hours by default; Fundray reuses the " +
                "existing point if Windows refuses a new one. All changes are logged to %ProgramData%\\Fundray\\logs."));

            return page;
        }

        private TabPage BuildTerminalTab()
        {
            var page = NewTab("Windows Terminal");
            var panel = NewPanel(page);

            int row = 0;
            AddTo(panel, row++, NewHeading("Windows Terminal configuration"));
            AddTo(panel, row++, NewText(
                "Adds a separate 'Fundray' profile to your existing Windows Terminal settings.json " +
                "(Cascadia Code font, dark color scheme, PowerShell startup, comfortable window size). " +
                "Your current profiles and settings are never overwritten - a timestamped backup is made first."));

            var buttons = NewFlow();
            var btnApply = NewButton("Apply Fundray Terminal profile", delegate { RunScript("terminal-config.ps1", "-Apply"); });
            var btnRestore = NewButton("Restore default Terminal settings", delegate { RunScript("terminal-config.ps1", "-Restore"); });
            btnApply.BackColor = Color.FromArgb(0, 120, 212);
            btnApply.ForeColor = Color.White;
            btnApply.FlatStyle = FlatStyle.Flat;
            buttons.Controls.Add(btnApply);
            buttons.Controls.Add(btnRestore);
            AddTo(panel, row++, buttons);

            AddTo(panel, row++, NewText(
                "Windows Terminal is not modified, replaced or downloaded by Fundray. If it is not installed, " +
                "the script tells you where to get it and exits cleanly."));

            return page;
        }

        private TabPage BuildAppearanceTab()
        {
            var page = NewTab("Appearance");
            var panel = NewPanel(page);

            int row = 0;
            AddTo(panel, row++, NewHeading("Interface beautification (safe & reversible)"));

            AddTo(panel, row++, NewSubHeading("Login background (registry method)"));
            AddTo(panel, row++, NewText(
                "Uses the documented OEMBackground registry value plus the oobe\\info\\backgrounds\\backgroundDefault.jpg " +
                "slot. Reliable on Windows 7; Windows 10/11 may ignore this method, and the script reports that honestly. " +
                "The image must be a JPG of at most 256 KB."));

            var buttons = NewFlow();
            buttons.Controls.Add(NewButton("Choose image and apply...", OnPickLoginBackground));
            AddTo(panel, row++, buttons);

            AddTo(panel, row++, NewSubHeading("Icons and themes (guides only)"));
            AddTo(panel, row++, NewText(
                "Fundray deliberately does NOT modify system files. Icon replacement and msstyles theming need " +
                "trusted third-party tools (for example Windhawk / Resource Redirect, or SecureUxTheme for themes). " +
                "The documentation links a recommended icon pack and a step-by-step guide."));

            var buttons2 = NewFlow();
            buttons2.Controls.Add(NewButton("Open icon pack guide", delegate { OpenUrl(RepoUrl + "#interface-beautification"); }));
            buttons2.Controls.Add(NewButton("Open theme guide", delegate { OpenUrl(RepoUrl + "#interface-beautification"); }));
            AddTo(panel, row++, buttons2);

            return page;
        }

        private TabPage BuildWindows11Tab()
        {
            var page = NewTab("Windows 11");
            var panel = NewPanel(page);

            int row = 0;
            var banner = NewHeading("Windows 11 support is currently in development. Stay tuned.");
            banner.ForeColor = Color.FromArgb(245, 192, 78);
            AddTo(panel, row++, banner);

            AddTo(panel, row++, NewText(
                "The Windows 11 Experience Pack is being built on the project website's Windows 11 page. " +
                "It will follow the same safety rules as the rest of Fundray: restore point first, " +
                "whitelist-only, fully logged and reversible. Nothing below is applied yet."));

            var chkMenu = NewCheck("Windows 11-style right-click menu toggle (planned)", false);
            var chkTaskbar = NewCheck("Taskbar alignment - center or left (planned)", false);
            chkMenu.Enabled = false;
            chkTaskbar.Enabled = false;
            AddTo(panel, row++, chkMenu);
            AddTo(panel, row++, chkTaskbar);

            AddTo(panel, row++, NewText(
                "These options ship with a future release. No Windows 11-specific downloads exist yet - " +
                "check the website for progress."));

            return page;
        }

        // ---------------------------------------------------------------- //
        //  Small UI helpers
        // ---------------------------------------------------------------- //
        private static TabPage NewTab(string title)
        {
            var page = new TabPage(title);
            page.Padding = new Padding(16);
            return page;
        }

        private static TableLayoutPanel NewPanel(TabPage page)
        {
            var panel = new TableLayoutPanel();
            panel.Dock = DockStyle.Fill;
            panel.ColumnCount = 1;
            panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
            panel.AutoScroll = true;
            page.Controls.Add(panel);
            return panel;
        }

        private static void AddTo(TableLayoutPanel panel, int row, Control control)
        {
            panel.RowCount = row + 1;
            panel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            control.Margin = new Padding(0, 4, 16, 10);
            control.MaximumSize = new Size(760, 0); // wrap long text instead of stretching the form
            control.AutoSize = true;
            panel.Controls.Add(control, 0, row);
        }

        private static Label NewHeading(string text)
        {
            return new Label { Text = text, Font = new Font("Segoe UI", 14F, FontStyle.Bold), AutoSize = true };
        }

        private static Label NewSubHeading(string text)
        {
            return new Label { Text = text, Font = new Font("Segoe UI", 11F, FontStyle.Bold), AutoSize = true };
        }

        private static Label NewText(string text)
        {
            return new Label { Text = text, ForeColor = Color.FromArgb(90, 96, 108), AutoSize = true };
        }

        private static CheckBox NewCheck(string text, bool isChecked)
        {
            return new CheckBox { Text = text, Checked = isChecked, AutoSize = true };
        }

        private static LinkLabel NewLink(string text, string url)
        {
            var link = new LinkLabel { Text = text, AutoSize = true, LinkBehavior = LinkBehavior.HoverUnderline };
            link.Links.Add(0, text.Length, url);
            link.LinkClicked += delegate(object sender, LinkLabelLinkClickedEventArgs e)
            {
                OpenUrl(e.Link.LinkData.ToString());
            };
            return link;
        }

        private static FlowLayoutPanel NewFlow()
        {
            return new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, AutoSize = true, WrapContents = true };
        }

        private Button NewButton(string text, EventHandler onClick)
        {
            var button = new Button { Text = text, AutoSize = true, Padding = new Padding(4) };
            button.Click += onClick;
            busyButtons.Add(button);
            return button;
        }

        // ---------------------------------------------------------------- //
        //  Administration
        // ---------------------------------------------------------------- //
        private static bool IsAdministrator()
        {
            try
            {
                WindowsIdentity identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch (Exception)
            {
                return false;
            }
        }

        private void CheckAdministrator()
        {
            if (IsAdministrator())
            {
                AppendLog("[OK] Running with administrator rights.");
                return;
            }

            AppendLog("[WARN] Fundray is not running as administrator. Optimizations need elevation.");
            DialogResult choice = MessageBox.Show(
                "Fundray works best as administrator (restore points, power plans, services).\n\nRestart as administrator now?",
                "Fundray",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (choice != DialogResult.Yes)
            {
                return;
            }

            try
            {
                var psi = new ProcessStartInfo();
                psi.FileName = Application.ExecutablePath;
                psi.Verb = "runas";
                psi.UseShellExecute = true;
                Process.Start(psi);
                Application.Exit();
            }
            catch (Exception)
            {
                AppendLog("[INFO] Elevation declined - continuing without administrator rights.");
            }
        }

        // ---------------------------------------------------------------- //
        //  Actions
        // ---------------------------------------------------------------- //
        private void OnCreateRestorePoint(object sender, EventArgs e)
        {
            AppendLog("[RESTORE] Creating system restore point 'Fundray baseline'...");
            SetBusy(true);
            string result = RunCapture(
                "Checkpoint-Computer -Description 'Fundray baseline' -RestorePointType MODIFY_SETTINGS; " +
                "if ($?) { 'RESTORE-POINT-OK' } else { 'RESTORE-POINT-SKIPPED-OR-FAILED' }");
            SetBusy(false);

            if (result.Contains("RESTORE-POINT-OK"))
            {
                AppendLog("[OK] System restore point created.");
                MessageBox.Show("System restore point created.", "Fundray",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            else
            {
                AppendLog("[WARN] Restore point was not confirmed: " + result);
                MessageBox.Show(
                    "Windows did not confirm a new restore point (System Restore may be disabled, or Windows " +
                    "reuses an existing point within 24 hours). Fundray can still continue - revert tools remain available.",
                    "Fundray", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private void OnApplyPerformance(object sender, EventArgs e)
        {
            if (!chkPowerPlan.Checked && !chkStartup.Checked && !chkServices.Checked &&
                !chkTemp.Checked && !chkVisuals.Checked)
            {
                MessageBox.Show("Select at least one optimization first.", "Fundray",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            // Safety rule: never optimize without a restore point.
            string countRaw = RunCapture(
                "\"if (Get-Command Get-ComputerRestorePoint -ErrorAction SilentlyContinue) { @(Get-ComputerRestorePoint).Count } else { 'N/A' }\"");
            int existingPoints;
            bool hasPoints = int.TryParse(countRaw, out existingPoints) && existingPoints > 0;

            if (!hasPoints)
            {
                DialogResult choice = MessageBox.Show(
                    "No system restore point was found.\n\nCreate one now before applying optimizations?",
                    "Fundray - restore point check",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Question);
                if (choice == DialogResult.Yes)
                {
                    OnCreateRestorePoint(sender, e);
                }
                else
                {
                    AppendLog("[ABORT] Optimization cancelled - user declined creating a restore point.");
                    return;
                }
            }

            var args = new StringBuilder();
            if (chkPowerPlan.Checked) { args.Append("-PowerPlan "); }
            if (chkStartup.Checked) { args.Append("-Startup "); }
            if (chkServices.Checked) { args.Append("-Services "); }
            if (chkTemp.Checked) { args.Append("-Temp "); }
            if (chkVisuals.Checked) { args.Append("-Visuals "); }
            if (chkKeepEffects.Checked) { args.Append("-KeepEffects "); }

            RunScript("optimize.ps1", args.ToString().Trim());
        }

        private void OnRevert(object sender, EventArgs e)
        {
            RunScript("revert.ps1", "");
        }

        private void OnPickLoginBackground(object sender, EventArgs e)
        {
            using (var dialog = new OpenFileDialog())
            {
                dialog.Title = "Choose a login background image";
                dialog.Filter = "JPEG images (*.jpg, *.jpeg)|*.jpg;*.jpeg";
                if (dialog.ShowDialog(this) != DialogResult.OK)
                {
                    return;
                }

                // Windows 7 requirement: JPEG, 256 KB or smaller.
                if (new FileInfo(dialog.FileName).Length > 256 * 1024)
                {
                    MessageBox.Show(
                        "The selected image is larger than 256 KB. On Windows 7 the login background must be a " +
                        "JPEG of at most 256 KB - please resize the image and try again.",
                        "Fundray", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }

                RunScript("appearance.ps1", "-SetLoginBackground \"" + dialog.FileName + "\"");
            }
        }

        // ---------------------------------------------------------------- //
        //  Script execution
        // ---------------------------------------------------------------- //
        private static string ScriptPath(string fileName)
        {
            return Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "scripts", fileName);
        }

        /// <summary>Runs a PowerShell script asynchronously and streams its output into the log.</summary>
        private void RunScript(string fileName, string arguments)
        {
            if (busy)
            {
                MessageBox.Show("Another operation is still running - please wait for it to finish.",
                    "Fundray", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            string path = ScriptPath(fileName);
            if (!File.Exists(path))
            {
                AppendLog("[ERROR] Script not found: " + path);
                MessageBox.Show("Script not found:\n" + path + "\n\nReinstall Fundray with install.bat.",
                    "Fundray", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            busy = true;
            SetBusy(true);
            AppendLog("[RUN ] powershell -File scripts\\" + fileName + " " + arguments);

            var psi = new ProcessStartInfo();
            psi.FileName = "powershell.exe";
            psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + path + "\" " + arguments;
            psi.UseShellExecute = false;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.CreateNoWindow = true;

            var process = new Process();
            process.StartInfo = psi;
            process.EnableRaisingEvents = true;
            process.OutputDataReceived += delegate(object s, DataReceivedEventArgs e)
            {
                if (!string.IsNullOrEmpty(e.Data)) { AppendLog("  " + e.Data); }
            };
            process.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e)
            {
                if (!string.IsNullOrEmpty(e.Data)) { AppendLog("  [PS-ERR] " + e.Data); }
            };
            process.Exited += delegate(object s, EventArgs e)
            {
                AppendLog("[EXIT] " + fileName + " finished (exit code " + process.ExitCode + ").");
                busy = false;
                try { BeginInvoke((MethodInvoker)delegate { SetBusy(false); }); }
                catch (Exception) { /* form is closing */ }
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
        }

        /// <summary>Runs a short PowerShell command synchronously and returns its trimmed output.</summary>
        private static string RunCapture(string command)
        {
            try
            {
                var psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command " + command;
                psi.UseShellExecute = false;
                psi.RedirectStandardOutput = true;
                psi.RedirectStandardError = true;
                psi.CreateNoWindow = true;

                using (var process = Process.Start(psi))
                {
                    string output = process.StandardOutput.ReadToEnd();
                    process.WaitForExit(120000);
                    return output.Trim();
                }
            }
            catch (Exception ex)
            {
                return string.Empty;
            }
        }

        // ---------------------------------------------------------------- //
        //  Logging
        // ---------------------------------------------------------------- //
        private static string LogFilePath()
        {
            string dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "Fundray", "logs");
            return Path.Combine(dir, "gui-" + DateTime.Now.ToString("yyyyMMdd") + ".log");
        }

        private void AppendLog(string message)
        {
            string line = string.Format("[{0:HH:mm:ss}] {1}", DateTime.Now, message);

            if (logBox != null)
            {
                if (logBox.InvokeRequired)
                {
                    try { logBox.BeginInvoke((MethodInvoker)delegate { AppendLogUi(line); }); }
                    catch (Exception) { /* form is closing */ }
                }
                else
                {
                    AppendLogUi(line);
                }
            }

            try
            {
                string path = LogFilePath();
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                File.AppendAllText(path, line + Environment.NewLine);
            }
            catch (Exception)
            {
                // Logging to disk is best-effort; the on-screen log is the primary surface.
            }
        }

        private void AppendLogUi(string line)
        {
            logBox.AppendText(line + Environment.NewLine);
        }

        private void SetBusy(bool isBusy)
        {
            foreach (Button button in busyButtons)
            {
                button.Enabled = !isBusy;
            }
            UseWaitCursor = isBusy;
        }

        // ---------------------------------------------------------------- //
        //  Misc
        // ---------------------------------------------------------------- //
        private static void OpenUrl(string url)
        {
            try
            {
                Process.Start(url);
            }
            catch (Exception)
            {
                MessageBox.Show("Please open this URL manually:\n" + url, "Fundray",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }
    }
}
