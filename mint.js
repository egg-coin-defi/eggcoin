let web3;
let vaultContract;

const VAULT_ADDRESS = "YOUR_VAULT_CONTRACT_ADDRESS";
const VAULT_ABI = [ ... ]; // Metti qui l'ABI del tuo contratto Vault

async function connectWallet() {
    if (window.ethereum) {
        web3 = new Web3(window.ethereum);
        try {
            const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
            document.getElementById("walletAddress").innerText = "Connected: " + accounts[0];
            document.getElementById("mintButton").disabled = false;
        } catch (err) {
            console.error("User denied connection.");
        }
    } else {
        alert("MetaMask not detected. Please install it.");
    }
}

function mintPair() {
    if (!web3) return alert("Please connect your wallet first");

    const mintButton = document.getElementById("mintButton");
    mintButton.disabled = true;
    mintButton.innerText = "⏳ Minting...";

    setTimeout(() => {
        mintButton.innerText = "✅ Pair Minted";
        document.getElementById("mintStatus").innerText = "You received 500 EGG$ + 500 CHI";
    }, 2000);
}