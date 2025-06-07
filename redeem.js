let web3;
let vaultContract;

const VAULT_ADDRESS = 'YOUR_VAULT_CONTRACT_ADDRESS';
const VAULT_ABI = [ ... ]; // Metti qui l'ABI del tuo Vault

async function connectWallet() {
    if (window.ethereum) {
        web3 = new Web3(window.ethereum);
        try {
            const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
            document.getElementById("walletAddress").innerText = "Connected: " + accounts[0];
            document.getElementById("redeemButton").disabled = false;
        } catch (err) {
            console.error("User denied connection.");
        }
    } else {
        alert("MetaMask not detected. Please install it first.");
    }
}

function redeemPair() {
    if (!web3) return alert("Please connect your wallet first.");

    const pairCount = parseInt(document.getElementById("pairCount").value);
    if (isNaN(pairCount) || pairCount <= 0) return alert("Enter a valid number of pairs.");

    const redeemButton = document.getElementById("redeemButton");
    redeemButton.disabled = true;
    redeemButton.innerText = "⏳ Burning...";
    
    // Simula il redeem – nella realtà chiama il contratto Solidity
    setTimeout(() => {
        redeemButton.innerText = "✅ Redeem Complete";
        document.getElementById("redeemStatus").innerText = 
            `You received ${pairCount}x $2.00 in crypto = $${pairCount * 2}`;
    }, 2000);
}