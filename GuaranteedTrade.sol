// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GuaranteedTrade {

    enum Status {
        NONE,
        FUNDED,
        FULFILLED,
        DISPUTED,
        RESOLVED,
        REFUNDED
    }

    struct Order {
        address buyer;
        address seller;
        uint256 amount;
        uint256 createdAt;
        uint256 deadline;
        Status status;
        bool disputed;
    }

    uint256 public nextOrderId;
    mapping(uint256 => Order) public orders;

    // EVENTS (for debugging & UI tracking)
    event OrderCreated(uint256 id, address buyer, address seller, uint256 amount);
    event OrderFulfilled(uint256 id);
    event DisputeRaised(uint256 id);
    event Resolved(uint256 id, string outcome);

    uint256 public constant TIME_LIMIT = 3 days; // can be adjusted

    // 🟢 Buyer places order and locks funds
    function createOrder(address _seller) external payable {
        require(msg.value > 0, "Send ETH");

        orders[nextOrderId] = Order({
            buyer: msg.sender,
            seller: _seller,
            amount: msg.value,
            createdAt: block.timestamp,
            deadline: block.timestamp + TIME_LIMIT,
            status: Status.FUNDED,
            disputed: false
        });

        emit OrderCreated(nextOrderId, msg.sender, _seller, msg.value);
        nextOrderId++;
    }

    // 🔵 Seller fulfills order
    function fulfillOrder(uint256 _id) external {
        Order storage o = orders[_id];

        require(msg.sender == o.seller, "Not seller");
        require(o.status == Status.FUNDED, "Invalid state");
        require(!o.disputed, "Cannot fulfill disputed order");

        o.status = Status.FULFILLED;
        payable(o.seller).transfer(o.amount);

        emit OrderFulfilled(_id);
    }

    // 🔴 Buyer raises dispute
    function raiseDispute(uint256 _id) external {
        Order storage o = orders[_id];

        require(msg.sender == o.buyer, "Only buyer can dispute");
        require(o.status == Status.FUNDED, "Cannot dispute fulfilled order");

        o.disputed = true;
        o.status = Status.DISPUTED;

        emit DisputeRaised(_id);
    }

    // ⚖️ Resolve dispute (only if dispute exists)
    function resolve(uint256 _id) external {
        Order storage o = orders[_id];
        require(o.status == Status.DISPUTED, "No dispute to resolve");

        // deterministic resolution
        if (o.status != Status.FULFILLED) {
            payable(o.buyer).transfer(o.amount);
            o.status = Status.RESOLVED;
            emit Resolved(_id, "Refunded Buyer");
        } else {
            payable(o.seller).transfer(o.amount);
            o.status = Status.RESOLVED;
            emit Resolved(_id, "Paid Seller");
        }
    }
}
