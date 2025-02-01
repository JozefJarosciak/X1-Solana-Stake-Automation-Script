![WARNING](https://img.shields.io/badge/IMPORTANT-WARNING-red)
<strong>Please read and fully understand this script before use; by running this code you assume all risks and the creator is not responsible for any damages or losses.</strong>

# X1/Solana Stake Automation Script

This script automates excess SOL staking on X1 or Solana by withdrawing funds from your vote account, creating & delegating it to a temporary stake account, and upon stake activation, merging it into your  existing 'main' stake account.
You can run this script on schedule to manage and optimize your staking. It performs the following steps:

1. **Withdraw Excess SOL:**  
   Withdraws any SOL above a configured minimum (default: 50 SOL) from a specified vote account.

2. **Create & Delegate Extra Stake:**  
   Creates a new stake account (if it doesn't exist) using the withdrawn funds, and delegates that stake to the same vote account.

3. **Monitor Stake Activation:**  
   Checks every 30 seconds until the extra stake becomes active.

4. **Merge Extra Stake:**  
   Once active, automatically merges the extra stake into a primary stake account.

The script logs all actions to a log file and also outputs the process to the terminal.

## Screenshot

![image](https://github.com/user-attachments/assets/c2560cdd-0532-4411-9b29-d7db0cbd1cc5)


---

## Prerequisites

- **Solana CLI:**  
  Ensure the [Solana CLI](https://docs.solana.com/cli/install-solana-cli-tools) is installed and properly configured.

- **jq:**  
  Install `jq` for JSON parsing:
  ```bash
  sudo apt-get update
  sudo apt-get install -y jq
  ```

### Keypair Files:
The following keypair files are required (adjust paths as necessary):
- Vote account address (configured in the script)
- Primary stake account keypair (e.g., /home/.config/solana/main-stake-account.json)
- Identity keypair (e.g., /home/.config/solana/identity.json)
- Withdraw authority keypair (e.g., /home/.config/solana/withdrawer.json)
- Extra stake account keypair (e.g., /home/.config/solana/temp_stake_account.json)  
  - The script will generate this file if it does not exist.

---

## Configuration
Edit the script `/home/stake_automation.sh` to set your parameters:

- **VOTE_ACCOUNT:**  
  The public address of your vote account.

- **PRIMARY_STAKE_ACCOUNT:**  
  The path to your primary stake account keypair file (e.g., `/home/.config/solana/main-stake-account.json`).

- **EXTRA_STAKE_ACCOUNT:**  
  The path to the extra stake account keypair file (e.g., `/home/.config/solana/temp_stake_account.json`).

- **WITHDRAWER_KEYPAIR:**  
  Path to your withdraw authority keypair (e.g., `/home/.config/solana/withdrawer.json`).

- **IDENTITY_KEYPAIR:**  
  Path to your identity keypair (e.g., `/home/.config/solana/identity.json`).

- **MIN_VOTE_BALANCE:**  
  The minimum SOL to keep in the vote account (default is 50 SOL).

- **LOG_FILE:**  
  The log file path (default is `/var/log/solana_stake_automation.log`).

---

## Usage

### Manual Execution
Run the script manually:
```bash
/home/stake_automation.sh
```

### Cron Job
To run the script automatically (e.g., hourly), add a cron job. Edit your crontab:
```bash
crontab -e
```
Add the following line:
```cron
0 * * * * /home/stake_automation.sh
```

---

## Logging
The script logs its output to `/var/log/solana_stake_automation.log` and echoes all actions to the terminal.

---

## Important Notes

- **Test with Small Amounts:**  
  Before using this script with high-value transactions, test it with smaller amounts to ensure everything works as expected.

- **Backups:**  
  Make sure you have secure backups of your keypair files.

- **Stake Activation:**  
  The script waits in 30-second intervals until the extra stake becomes active before attempting a merge. This may take some time depending on network conditions.

---

## License
This project is licensed under the MIT License.
