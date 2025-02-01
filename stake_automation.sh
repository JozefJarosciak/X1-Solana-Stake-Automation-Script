#!/bin/bash

# ------------------------------------------------------------------------------
# Script Name: stake_automation.sh
# Description: Withdraws any excess SOL (over 50 SOL) from the vote account,
#              creates a stake account (temp_stake_account.json) with the withdrawn funds,
#              delegates that stake to the vote account, then every 30 seconds
#              checks if the stake is active. When active, it merges it into the
#              primary stake account (main-stake-account.json) and completes the job.
# Schedule: Set as a cron job to run hourly (or run continuously).
# ------------------------------------------------------------------------------

# --------------------------- Configuration Variables --------------------------

# Your Vote Account Address
VOTE_ACCOUNT=""

# Primary Stake Account Keypair Path (create this stake account if you don't have it already to merge into)
PRIMARY_STAKE_ACCOUNT="/home/.config/solana/main-stake-account.json"

# Temporary Stake Account Keypair Path (for new stake deposits)
EXTRA_STAKE_ACCOUNT="/home/.config/solana/temp_stake_account.json"

# Withdraw Authority Keypair Path
WITHDRAWER_KEYPAIR="/home/.config/solana/withdrawer.json"

# Identity Keypair Path (System Account)
IDENTITY_KEYPAIR="/home/.config/solana/identity.json"

# Minimum vote account balance to keep (SOL)
MIN_VOTE_BALANCE=50

# Log File Path
LOG_FILE="/var/log/solana_stake_automation.log"

# ------------------------------ Helper Functions ------------------------------
# Function to log messages with timestamps to both screen and log file
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# ------------------------------- Main Script ----------------------------------
# Ensure the log file exists
touch "$LOG_FILE"

# Step 1: Get the current balance of the vote account
vote_balance=$(solana balance "$VOTE_ACCOUNT" | awk '{print $1}')
log "Vote account balance: $vote_balance SOL"

# Step 2: Calculate the excess amount to withdraw (any amount above MIN_VOTE_BALANCE)
withdraw_amount=$(echo "$vote_balance - $MIN_VOTE_BALANCE" | bc)
log "Calculated withdraw amount (excess over $MIN_VOTE_BALANCE SOL): $withdraw_amount SOL"

# Check if the withdraw amount is positive
is_positive=$(echo "$withdraw_amount > 0" | bc)
if [ "$is_positive" -ne 1 ]; then
    log "Withdraw amount ($withdraw_amount SOL) is not greater than 0. Exiting."
    exit 0
fi

# Step 3: Withdraw SOL from the vote account to the identity account
log "Initiating withdrawal of $withdraw_amount SOL from vote account to system account."
withdraw_tx=$(solana withdraw-from-vote-account \
    "$VOTE_ACCOUNT" \
    "$(solana-keygen pubkey "$IDENTITY_KEYPAIR")" \
    "$withdraw_amount" \
    --authorized-withdrawer "$WITHDRAWER_KEYPAIR" \
    --fee-payer "$WITHDRAWER_KEYPAIR" \
    --output json 2>> "$LOG_FILE")

if [ $? -ne 0 ]; then
    log "Error: Failed to withdraw $withdraw_amount SOL from vote account."
    exit 1
fi

tx_signature=$(echo "$withdraw_tx" | jq -r '.result')
log "Withdrawal transaction signature: $tx_signature"

# Step 4: Ensure the extra stake keypair exists; if not, create it
if [ ! -f "$EXTRA_STAKE_ACCOUNT" ]; then
    log "Extra stake keypair not found. Generating new keypair at $EXTRA_STAKE_ACCOUNT."
    solana-keygen new -o "$EXTRA_STAKE_ACCOUNT" --no-bip39-passphrase --force
fi

# Step 5: Create the extra stake account using the withdrawn funds
log "Creating stake account $EXTRA_STAKE_ACCOUNT with $withdraw_amount SOL."
create_tx=$(solana create-stake-account "$EXTRA_STAKE_ACCOUNT" "$withdraw_amount" \
    --from "$IDENTITY_KEYPAIR" \
    --stake-authority "$IDENTITY_KEYPAIR" \
    --withdraw-authority "$IDENTITY_KEYPAIR" \
    --output json 2>> "$LOG_FILE")

if [ $? -ne 0 ]; then
    log "Error: Failed to create stake account $EXTRA_STAKE_ACCOUNT."
    exit 1
fi

tx_signature_create=$(echo "$create_tx" | jq -r '.signature')
log "Stake account creation transaction signature: $tx_signature_create"

# Step 6: Delegate the extra stake account to the vote account
log "Delegating stake from $EXTRA_STAKE_ACCOUNT to vote account $VOTE_ACCOUNT."
delegate_tx=$(solana delegate-stake "$EXTRA_STAKE_ACCOUNT" "$VOTE_ACCOUNT" \
    --stake-authority "$IDENTITY_KEYPAIR" \
    --output json 2>> "$LOG_FILE")

if [ $? -ne 0 ]; then
    log "Error: Failed to delegate stake from $EXTRA_STAKE_ACCOUNT."
    exit 1
fi

tx_signature_delegate=$(echo "$delegate_tx" | jq -r '.signature')
log "Delegation transaction signature: $tx_signature_delegate"

# Step 7: Wait (check every 30 seconds) until the extra stake account becomes active
log "Checking extra stake account activation status every 30 seconds."
while true; do
    extra_status=$(solana stake-account "$EXTRA_STAKE_ACCOUNT" --output json)
    active_stake=$(echo "$extra_status" | jq -r '.activeStake // 0')
    log "Current extra stake activeStake: $active_stake lamports."
    if [ "$active_stake" -gt 0 ]; then
        log "Extra stake account is active."
        break
    fi
    sleep 30
done

# Step 8: Merge the extra stake account into the primary stake account
primary_pubkey=$(solana-keygen pubkey "$PRIMARY_STAKE_ACCOUNT")
log "Merging extra stake ($EXTRA_STAKE_ACCOUNT) into primary stake account ($primary_pubkey)."
merge_tx=$(solana merge-stake "$primary_pubkey" "$EXTRA_STAKE_ACCOUNT" \
    --stake-authority "$IDENTITY_KEYPAIR" \
    --output json 2>> "$LOG_FILE")

if [ $? -ne 0 ]; then
    log "Error: Failed to merge $EXTRA_STAKE_ACCOUNT into $PRIMARY_STAKE_ACCOUNT."
    exit 1
fi

tx_signature_merge=$(echo "$merge_tx" | jq -r '.signature')
log "Merge transaction signature: $tx_signature_merge"

log "Stake automation run complete."
exit 0
