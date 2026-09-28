package cmd

import (
	"fmt"
	"os"
	"strings"

	"github.com/InazumaV/V2bX/common/exec"
	"github.com/spf13/cobra"
)

var targetVersion string

var (
	updateCommand = cobra.Command{
		Use:   "update",
		Short: "Update V2bX version",
		Run: func(_ *cobra.Command, _ []string) {
			exec.RunCommandStd("bash",
				"-c",
				`installer=$(mktemp /tmp/v2bx-installer.XXXXXX) || exit 1
trap 'rm -f "$installer"' EXIT
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 \
  --output "$installer" https://raw.githubusercontent.com/phungvanquy/v2bx-new/refs/heads/main/scripts/install.sh &&
  bash -n "$installer" && bash "$installer" "$1"`,
				"v2bx-update",
				targetVersion)
		},
		Args: cobra.NoArgs,
	}
	uninstallCommand = cobra.Command{
		Use:   "uninstall",
		Short: "Uninstall V2bX",
		Run:   uninstallHandle,
	}
)

func init() {
	updateCommand.PersistentFlags().StringVar(&targetVersion, "version", "", "update target version")
	command.AddCommand(&updateCommand)
	command.AddCommand(&uninstallCommand)
}

func uninstallHandle(_ *cobra.Command, _ []string) {
	var yes string
	fmt.Println(Warn("Are you sure you want to uninstall V2bX? (Y/n)"))
	fmt.Scan(&yes)
	if strings.ToLower(yes) != "y" {
		fmt.Println("Uninstallation canceled")
	}
	_, err := exec.RunCommandByShell("systemctl stop V2bX&&systemctl disable V2bX")
	if err != nil {
		fmt.Println(Err("exec cmd error: ", err))
		fmt.Println(Err("Failed to uninstall V2bX"))
		return
	}
	_ = os.RemoveAll("/etc/systemd/system/V2bX.service")
	_ = os.RemoveAll("/etc/V2bX/")
	_ = os.RemoveAll("/usr/local/V2bX/")
	_ = os.RemoveAll("/bin/V2bX")
	_, err = exec.RunCommandByShell("systemctl daemon-reload&&systemctl reset-failed")
	if err != nil {
		fmt.Println(Err("exec cmd error: ", err))
		fmt.Println(Err("Failed to uninstall V2bX"))
		return
	}
	fmt.Println(Ok("V2bX uninstalled successfully"))
}
