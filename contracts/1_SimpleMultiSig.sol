// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event Execute(uint indexed txId);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notApproved(uint _txId) {
        require(!approved[_txId][msg.sender], "tx already approved");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "tx already executed");
        _;
    }
    
    modifier isApprovedByRequired(uint _txId) {
        uint approvals = 0;
        uint ownerId = 0;
        while (approvals < required) {
            if(approved[_txId][owners[ownerId]]) approvals += 1;
            ownerId += 1;
        }
        require(approvals == required);
        _;
    }
    
    modifier isApprovedBySender(uint _txId) {
        require(approved[_txId][msg.sender]);
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(
            _required > 0 && _required <= _owners.length,
            "invalid required number of owners"
        );

        for (uint i; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner is not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }
    
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
    
    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner {
        Transaction memory proposedTx = Transaction(_to, _value, _data, false);
        transactions.push(proposedTx);
        emit Submit(transactions.length - 1);
    }
    
    function approve(uint _txId) external onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId) {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }
    
    function execute(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) isApprovedByRequired(_txId) {
        (bool success, ) = transactions[_txId].to.call{value: transactions[_txId].value}(transactions[_txId].data);
        if(!success) {
            revert();
        }
        transactions[_txId].executed = true;
        emit Execute(_txId);
    }
    
    function revoke(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) isApprovedBySender(_txId) {
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }
}
