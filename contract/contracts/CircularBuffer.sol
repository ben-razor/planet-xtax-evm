// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

/** 
 * @dev A small cicular buffer
 * @dev ONLY SUPPORTS UP TO 128 elems ALLOW NEGATIVE INDEXING 
 */
library CircularBuffer {

    struct Buf {
        /// @dev Index of an item ONLY SUPPORTS HALF RANGE 0-127 TO ALLOW NEGATIVE INDEXING
        uint8 idx;
        /// @dev Size of buffer
        uint8 numElems;
        /// @dev The stored items
        uint256[] elems;
    }

    /// @dev Increment the index and store a value at that position
    function insert(Buf storage cb, uint256 val) internal {
        int8 idx = wrap(int8(cb.idx) + 1, 0, int8(cb.numElems) - 1); 
        cb.idx = uint8(idx);
        cb.elems[cb.idx] = val;
    }

    /// @dev Erase an item at a given offset relative to the current position
    function erase(Buf storage cb, int8 offset) internal {
        int8 offs = wrap(int8(cb.idx) - offset, 0, int8(cb.numElems) - 1); 
        delete cb.elems[uint8(offs)];
    }

    /// @dev Read an item at a given offset relative to the current position
    function read(Buf storage cb, int8 offset) internal view returns(uint256) {
        int8 offs = wrap(int8(cb.idx) - offset, 0, int8(cb.numElems) - 1); 
        return cb.elems[uint8(offs)];
    }

    /// @dev Helper function to wrap the index past the end of the buffer
    function wrap(int8 val, int8 start, int8 end) internal pure returns(int8) {

        if(val > end) val = start + (val % (end + 1));
        else if(val < start) val = end - ((start - (val + 1)) % end);

        return val;
    }
}

