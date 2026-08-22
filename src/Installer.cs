using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

namespace DshInstaller
{
    internal static class Program
    {
        private static readonly string[] ResourceNames =
        {
            "install.ps1",
            "launch-dsh.cmd",
            "dsh.ico",
        };

        private static void Main(string[] args)
        {
            // Re-launch as administrator only when Node.js is missing (the Node MSI
            // installer needs elevation). If Node.js already exists, a per-user npm
            // global install works without admin rights.
            if (!IsElevated() && !NodeExists())
            {
                if (RelaunchElevated())
                    return; // the elevated copy is now running the installer
            }

            Console.WriteLine();
            Console.WriteLine("============================================================");
            Console.WriteLine("   DeepSeek Harness (dsh)  -  One-Click Installer");
            Console.WriteLine("============================================================");
            Console.WriteLine();

            string tempDir = Path.Combine(Path.GetTempPath(), "dsh-install-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);

            try
            {
                ExtractResources(tempDir);

                string installScript = Path.Combine(tempDir, "install.ps1");
                if (!File.Exists(installScript))
                {
                    Console.Error.WriteLine("[DSH] Could not extract the installer payload.");
                    Console.WriteLine("Press Enter to exit...");
                    Console.ReadLine();
                    Environment.Exit(1);
                }

                bool silent = Array.IndexOf(args, "--silent") >= 0 || Array.IndexOf(args, "-silent") >= 0;
                string psArgs = "-NoProfile -ExecutionPolicy Bypass -File \"" + installScript + "\"";
                if (silent) psArgs += " -Silent";

                var psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = psArgs,
                    WorkingDirectory = tempDir,
                    UseShellExecute = false,
                    CreateNoWindow = false,
                    WindowStyle = ProcessWindowStyle.Normal
                };

                var proc = Process.Start(psi);
                if (proc == null)
                {
                    Console.Error.WriteLine("[DSH] Could not start the installer.");
                    Console.WriteLine("Press Enter to exit...");
                    Console.ReadLine();
                    Environment.Exit(1);
                }
                proc.WaitForExit();
                Environment.Exit(proc.ExitCode);
            }
            finally
            {
                try { Directory.Delete(tempDir, true); } catch { /* best effort */ }
            }
        }

        private static void ExtractResources(string targetDir)
        {
            Assembly asm = Assembly.GetExecutingAssembly();
            foreach (string name in ResourceNames)
            {
                using (Stream stream = asm.GetManifestResourceStream(name))
                {
                    if (stream == null)
                        continue;
                    string dest = Path.Combine(targetDir, name);
                    using (var file = new FileStream(dest, FileMode.Create, FileAccess.Write))
                    {
                        stream.CopyTo(file);
                    }
                }
            }
        }

        private static bool IsElevated()
        {
            using (var identity = System.Security.Principal.WindowsIdentity.GetCurrent())
            {
                var principal = new System.Security.Principal.WindowsPrincipal(identity);
                return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
            }
        }

        private static bool RelaunchElevated()
        {
            var psi = new ProcessStartInfo
            {
                FileName = Process.GetCurrentProcess().MainModule.FileName,
                UseShellExecute = true,
                Verb = "runas",
                WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory
            };
            try
            {
                Process.Start(psi);
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static bool NodeExists()
        {
            string[] candidates =
            {
                "node",
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "nodejs", "node.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "nodejs", "node.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "nodejs", "node.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "nodejs", "node.exe")
            };
            foreach (string c in candidates)
            {
                if (c == "node")
                {
                    try
                    {
                        var psi = new ProcessStartInfo("where.exe", "node")
                        {
                            UseShellExecute = false,
                            RedirectStandardOutput = true,
                            CreateNoWindow = true
                        };
                        using (var p = Process.Start(psi))
                        {
                            if (p != null)
                            {
                                p.WaitForExit(5000);
                                return p.ExitCode == 0;
                            }
                        }
                    }
                    catch { /* fall through */ }
                }
                else if (File.Exists(c))
                {
                    return true;
                }
            }
            return false;
        }
    }
}
