// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

contract TicketingSystem {
    struct artist {
        bytes32 name;
        uint256 artistCategory;
        address owner;
        uint256 totalTicketSold;
    }
    struct venue {
        bytes32 name;
        uint256 capacity;
        uint256 standardComission;
        address payable owner;
    }
    struct concert {
        uint256 artistId;
        uint256 venueId;
        uint256 concertDate;
        uint256 ticketPrice;
        //not declared by user
        bool validatedByArtist;
        bool validatedByVenue;
        uint256 totalSoldTicket;
        uint256 totalMoneyCollected;
    }

    struct ticket {
        uint256 concertId;
        address payable owner;
        bool isAvailable;
        bool isAvailableForSale;
        uint256 amountPaid;
    }

    uint256 public artistCount = 0;
    uint256 public venueCount = 0;
    uint256 public concertCount = 0;
    uint256 public ticketCount = 0;

    //MAPPINGS & ARRAYS
    mapping(uint256 => artist) public artistsRegister;
    mapping(bytes32 => uint256) private artistsID;

    mapping(uint256 => venue) public venuesRegister;
    mapping(bytes32 => uint256) private venuesID;

    mapping(uint256 => concert) public concertsRegister;

    mapping(uint256 => ticket) public ticketsRegister;

    //EVENTS
    event CreatedArtist(bytes32 name, uint256 id);
    event ModifiedArtist(bytes32 name, uint256 id, address sender);
    event CreatedVenue(bytes32 name, uint256 id);
    event ModifiedVenue(bytes32 name, uint256 id);
    event CreatedConcert(uint256 concertDate, bytes32 name, uint256 id);

    constructor() {}

    function createArtist(bytes32 _artistName, uint256 _artistCategory) public {
        artistCount++;
        artistsRegister[artistCount] = artist(_artistName, _artistCategory, msg.sender, 0);
        artistsID[_artistName] = artistCount;
        emit CreatedArtist(_artistName, artistCount);
    }

    function modifyArtist(uint _artistId, bytes32 _name, uint _artistCategory, address payable _newOwner) public {
        require(artistsRegister[_artistId].owner == msg.sender, "not the owner");
        uint256 currentTotalTicketSold = artistsRegister[_artistId].totalTicketSold;
        artistsRegister[_artistId] = artist(_name,_artistCategory, _newOwner,currentTotalTicketSold);
        emit ModifiedArtist(_name, _artistId, msg.sender);
    }
    function createVenue(bytes32 _name, uint256 _capacity, uint256 _standardComission) public {
        venueCount++;
        venuesRegister[venueCount] = venue(_name, _capacity, _standardComission, payable(msg.sender));
        venuesID[_name] = venueCount;
        emit CreatedVenue(_name, venueCount);
    }

    function modifyVenue(uint256 _venueId, bytes32 _name, uint256 _capacity, uint256 _standardComission, address payable _newOwner) public {
        require(venuesRegister[_venueId].owner == payable(msg.sender), "not the venue owner");
        venuesRegister[_venueId] = venue(_name,_capacity,_standardComission,_newOwner);
        emit ModifiedVenue(_name, _venueId);
    }

    //FUNCTIONS TEST 3 -- CONCERTS
    function createConcert(uint256 _artistId, uint256 _venueId, uint256 _concertDate, uint256 _ticketPrice) public {
        concertCount++;
        bool validatedByArtist1 = false;
        bool validatedByVenue1 = false;
        if(artistsRegister[_artistId].owner == msg.sender){
            validatedByArtist1 = true;
        }
        if(venuesRegister[_venueId].owner == msg.sender){
            validatedByVenue1 = true;
        }
        concertsRegister[concertCount] = concert(_artistId,_venueId,_concertDate,_ticketPrice,validatedByArtist1,validatedByVenue1,0,0);
        emit CreatedConcert(_concertDate, artistsRegister[_artistId].name, concertCount);
    }

    function validateConcert(uint256 _concertId) public {
        concert storage tmpConcert = concertsRegister[_concertId];
        

        // Validate the concert
        if (artistsRegister[tmpConcert.artistId].owner == msg.sender) {
            tmpConcert.validatedByArtist = true;
        }
        if (venuesRegister[tmpConcert.venueId].owner == msg.sender) {
            tmpConcert.validatedByVenue = true;
        }
    }

    function emitTicket(uint _concertId, address payable _ticketOwner) public {
        concert storage tmpConcert = concertsRegister[_concertId];
        require(artistsRegister[tmpConcert.artistId].owner == msg.sender, "not the owner");
        tmpConcert.totalSoldTicket++;
        ticketCount++;
        ticketsRegister[ticketCount] = ticket(_concertId, _ticketOwner, true, false, 0);
    }

    function useTicket(uint256 _ticketId) public {
        ticket storage tmpTicket = ticketsRegister[_ticketId];
        require(tmpTicket.owner == payable(msg.sender), "sender should be the owner");
        require(block.timestamp + 60*60*24 >= concertsRegister[tmpTicket.concertId].concertDate, "should be used the d-day");
        require(concertsRegister[tmpTicket.concertId].validatedByVenue, "should be validated by the venue");
        // Mark the ticket as used
        tmpTicket.isAvailable = false;
        // Optionally, reset the owner to free up state storage and possibly get a gas refund
        tmpTicket.owner = payable(address(0));
    }

    //FUNCTIONS TEST 4 -- BUY/TRANSFER
    function buyTicket(uint256 _concertId) public payable {
        require(concertsRegister[_concertId].ticketPrice == msg.value,"not the right price");
        concertsRegister[_concertId].totalSoldTicket++;
        concertsRegister[_concertId].totalMoneyCollected += msg.value;
        ticketCount++;
        ticketsRegister[ticketCount] = ticket(_concertId, payable(msg.sender), true, false, msg.value);
    }
    function transferTicket(uint256 _ticketId, address payable _newOwner) public {
        require(ticketsRegister[_ticketId].owner == payable(msg.sender), "not the ticket owner");
        ticketsRegister[_ticketId].owner = _newOwner;
    }
    //FUNCTIONS TEST 5 -- CONCERT CASHOUT
    function cashOutConcert(uint256 _concertId, address payable _cashOutAddress) public {
        require(block.timestamp >= concertsRegister[_concertId].concertDate,"should be after the concert");
        require(artistsRegister[concertsRegister[_concertId].artistId].owner == msg.sender, "should be the artist");
        
        uint256 totalTicketSales = concertsRegister[_concertId].ticketPrice * concertsRegister[_concertId].totalSoldTicket;
        uint256 venueShare = (totalTicketSales * venuesRegister[concertsRegister[_concertId].venueId].standardComission) / 10000;
        uint256 artistShare = totalTicketSales - venueShare;

        _cashOutAddress.call{value: artistShare}("");
        venuesRegister[concertsRegister[_concertId].venueId].owner.call{value: venueShare}("");

        artistsRegister[concertsRegister[_concertId].artistId].totalTicketSold += concertsRegister[_concertId].totalSoldTicket;
    }

    //FUNCTIONS TEST 6 -- TICKET SELLING
    function offerTicketForSale(uint256 _ticketId, uint256 _salePrice) public {
        ticket storage tmpTicket = ticketsRegister[_ticketId];
        require(tmpTicket.owner == payable(msg.sender), "should be the owner");
        require(_salePrice <= tmpTicket.amountPaid, "should be less than the amount paid");
        tmpTicket.isAvailableForSale = true;
        tmpTicket.amountPaid = _salePrice;
    }

    function buySecondHandTicket(uint256 _ticketId) public payable {
        ticket storage tmpTicket = ticketsRegister[_ticketId];
        require(tmpTicket.isAvailable, "should be available");
        require(msg.value >= tmpTicket.amountPaid, "not enough funds");

        address payable previousOwner = tmpTicket.owner;
        tmpTicket.owner = payable(msg.sender);

        previousOwner.call{value: tmpTicket.amountPaid}("");

        tmpTicket.isAvailableForSale = false;
        tmpTicket.amountPaid = 0; 
    }
}