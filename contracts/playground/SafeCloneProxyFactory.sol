pragma solidity ^0.4.24;

contract Storage {
    bool public initialized;
    address public target;
    address public owner;

    modifier onlyOnce () {
        require (initialized == false);
        initialized = true;
        _;
    }
    modifier onlyOwner () {
        require (msg.sender == owner);
        _;
    }
}

contract Name is Storage {
    uint8 public value;

    function setValue(uint8 _value) public {
        value = _value;
    }
}

contract NamePayable is Storage {
    uint8 public value;

    function setValue(uint8 _value) public payable {
        value = _value;
    }
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract SWProxy is Storage {

    function getCreator() pure public returns (address) {
        return 2;
    }

    function setTarget(address _target) onlyOwner() public {
        target = _target;
    }

    modifier onlyCreator () {
        require (msg.sender == getCreator());
        _;
    }

    function init(address _owner, address _target) onlyOnce() public {
        owner = _owner;
        target = _target;
    }

    function getIt(uint256 value) view public returns (uint256) {
        return 2;
    }

    function getIt2(uint256 value) view public returns (uint256) {
        return 3;
    }

    function () payable public {
        bytes memory data = msg.data;
        address impl = target;

        if (data.length != 0x0) {
            // solium-disable-next-line security/no-inline-assembly
            assembly {
                let result := delegatecall(gas, impl, add(data, 0x20), mload(data), 0, 0)
                let size := returndatasize

                let ptr := mload(0x40)
                returndatacopy(ptr, 0, size)

                switch result
                case 0 { revert(ptr, size) }
                default { return(ptr, size) }
            }
        }
    }
}

contract CloneFactory {

    event CloneCreated(address indexed target, address clone);

    function createClone(address creator, address target) public returns (address result) {
        bytes memory
        //clone = hex"600034603b57603080600f833981f36000368180378080368173bebebebebebebebebebebebebebebebebebebebe5af43d82803e15602c573d90f35b3d90fd";

        //clone = hex"600160205160015401546102a03660a073bebebebebebebebebebebebebebebebebebebebe5af414602f57600080fd5b60205160015401541515603e57005b60205160015401546102a0f3";
        //clone =   hex"604b80600c6000396000f300600160205160015401546102a03660a073bebebebebebebebebebebebebebebebebebebebe5af414602f57600080fd5b60205160015401541515603e57005b60205160015401546102a0f3";
        //clone =   hex"602c80600c6000396000f30060006102a03660003573bebebebebebebebebebebebebebebebebebebebe5af4506102a060005260206000f3";
        //clone =     hex"602580600c6000396000f300602060003660003573bebebebebebebebebebebebebebebebebebebebe5af45060206000f3";
        //clone = hex"600c80600c6000396000f3006202323460005260326000f3";


        //clone = hex"600b80600c6000396000f30036600060203760206024f3";
        //clone =   hex"603680600c6000396000f300600060205260046020601c373660006040376020604036604073bebebebebebebebebebebebebebebebebebebebe5af45060206040f3";
        //clone =   hex"602a80600c6000396000f3003660006040376020604036604073bebebebebebebebebebebebebebebebebebebebe5af45060206040f3";
        //clone =   hex"603080600c6000396000f30073bebebebebebebebebebebebebebebebebebebebe604052366000606037602060603660606040515af45060206060f3";
        //clone =   hex"604280600c6000396000f30073bebebebebebebebebebebebebebebebebebebebe604052600060205260046000603c37366000608037602060803660806040515af45060205160805260206080f3";
        //clone   = hex"603080600f833981f36000368180378080368173bebebebebebebebebebebebebebebebebebebebe5af43d82803e15602c573d90f35b3d90fd";
        //clone =  hex"603480600c6000396000f30073bebebebebebebebebebebebebebebebebebebebe6040523660006080376000803660806040515af4503d600060803e3d6080f3";
        //clone = hex"604280600c6000396000f30073bebebebebebebebebebebebebebebebebebebebe6040523660006080376000803660806040515af46060523d600060803e60605115603d573d6080f35b3d6080fd";
        //clone = hex"604280600c6000396000f30073bebebebebebebebebebebebebebebebebebebebe6040523660006080376000803660806040515af46060523d600060803e60605115603d573d6080f35b3d6080fd";
        //clone = hex"606180600c6000396000f30073bebebebebebebebebebebebebebebebebebebebe604052600060205260046000603c37630ee2cb10602051141560365760206040f35b3660006080376000803660806040515af46060523d600060803e60605115605c573d6080f35b3d6080fd";
        clone = hex"607980600c6000396000f30073bebebebebebebebebebebebebebebebebebebebe604052600060205260046000603c37630ee2cb106020511415604e5773dadadadadadadadadadadadadadadadadadadada60005260206000f35b3660006080376000803660806040515af46060523d600060803e606051156074573d6080f35b3d6080fd";
        //bytes memory clone_solidity = hex"6080602036601f8101829004820282018301604052808352606092916000919081908401838280828437820191505050505050905060008082516020840170bebebebebebebebebebebebebebebebebe5af43d604051816000823e82600081146066578282f35b8282fd00a165627a7a72305820be35e07a7c168a1bfefe3147abbaa84b6d74fe75a76007961fc46f66cfce904e0029";
        bytes20 targetBytes = bytes20(target);
        bytes20 creatorBytes = bytes20(creator);
        for (uint i = 0; i < 20; i++) {
            //clone[26 + i] = targetBytes[i];
            clone[13 + i] = targetBytes[i];
            clone[62 + i] = creatorBytes[i];
            //clone_solidity[63 + i] = targetBytes[i];
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            //let len := mload(clone_solidity)
            //let data := add(clone_solidity, 0x20)
            let len := mload(clone)
            let data := add(clone, 0x20)
            result := create(0, data, len)
        }
    }
}

contract SWProxyFactory is CloneFactory {
    address public swProxy;
    mapping(address => address) public clones;

    constructor() public {
        swProxy = new SWProxy();
    }

    function clone(address _target) public {
        address _clone = clones[msg.sender];
        if (_clone == address(0)) {
            _clone = createClone(address(this), swProxy);
            require(_clone != address(0));
            clones[msg.sender] = _clone;
            SWProxy(_clone).init(msg.sender, _target);
        }
    }
}

contract Proxy {
    function () payable public {
        bytes memory data = msg.data;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let result := delegatecall(gas, 0xbebebebebebebebebebebebebebebebebe, add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}

contract Empty {
}

contract Const {
    address public constant x = 0xbebebebebebebebebebebebebebebebebebebebe;
}

