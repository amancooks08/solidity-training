// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

contract HelloWorld {
  /**
   * @dev Prints Hello World string
   */
  string public message;

  
  constructor(string memory initMessage) {
    message = initMessage;
  }

  function update(string memory newMessage) public {
    message = newMessage;
  }
}
