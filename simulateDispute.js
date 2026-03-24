const { ethers } = require("hardhat");

async function main() {
    // Get test accounts
    const [deployer, buyer, seller] = await ethers.getSigners();

    // Deploy contract
    const Trade = await ethers.getContractFactory("GuaranteedTrade", deployer);
    const trade = await Trade.deploy();
    await trade.deployed();
    console.log("Contract deployed at:", trade.address);

    // 1️⃣ Buyer creates order
    const txCreate = await trade.connect(buyer).createOrder(seller.address, {
        value: ethers.utils.parseEther("1")
    });
    await txCreate.wait();
    console.log("Order created by buyer:", buyer.address);

    // Check order state
    let order = await trade.orders(0);
    console.log("Order after creation:", {
        buyer: order.buyer,
        seller: order.seller,
        amount: ethers.utils.formatEther(order.amount),
        status: order.status.toString(),
        disputed: order.disputed
    });

    // 2️⃣ Seller fails to fulfill → simulate dispute
    console.log("Seller does nothing... buyer raises dispute");

    const txDispute = await trade.connect(buyer).raiseDispute(0);
    await txDispute.wait();

    order = await trade.orders(0);
    console.log("Order after dispute:", {
        status: order.status.toString(),
        disputed: order.disputed
    });

    // 3️⃣ Resolve dispute
    const txResolve = await trade.connect(deployer).resolve(0);
    await txResolve.wait();

    order = await trade.orders(0);
    console.log("Order after resolution:", {
        status: order.status.toString(),
        disputed: order.disputed
    });

    // 4️⃣ Check balances
    const buyerBalance = await ethers.provider.getBalance(buyer.address);
    const sellerBalance = await ethers.provider.getBalance(seller.address);

    console.log("Buyer balance after resolution:", ethers.utils.formatEther(buyerBalance));
    console.log("Seller balance after resolution:", ethers.utils.formatEther(sellerBalance));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
