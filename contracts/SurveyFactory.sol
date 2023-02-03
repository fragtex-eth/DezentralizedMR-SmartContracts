//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./SurveyUpgradable.sol";

contract SurveyFactory is SurveyUpgradable {
    address public surveyImplementation;

    address[] public allSurveys;
    mapping(address => uint) internal indexOfSurvey;
    mapping(address => bool) internal isSurvey;
    mapping(address => bool) internal surveyFinished;
    mapping(address => address[]) internal participatedSurveys; //Surveys a user participated in and has not received payment

    modifier onlySurvey() {
        require(isSurvey[msg.sender], "Only surveys can call this function");
        _;
    }

    constructor(address _surveyImplementation) {
        surveyImplementation = _surveyImplementation;
    }

    function createSurvey(
        string[] memory _questions,
        uint256 _participants,
        uint256 _endTime,
        uint256 _reviewNeeded,
        uint256 _capital
    ) external payable returns (address survey) {
        require(
            msg.value == _capital,
            "Amount in the message is not equal to the amount specified"
        );
        bytes32 salt = keccak256(
            abi.encodePacked(_participants, _endTime, _reviewNeeded, _capital)
        );
        survey = Clones.cloneDeterministic(surveyImplementation, salt);
        SurveyUpgradable(survey).initialize(
            _participants,
            _endTime,
            _reviewNeeded,
            _capital
        );
        SurveyUpgradable(survey).setQuestions(_questions);
        indexOfSurvey[survey] = allSurveys.length;
        allSurveys.push(survey);
        isSurvey[survey] = true;
    }

    //Survey will add Participants and Reviewers for them to be able to withdraw
    function addSurveyCompleted(address _participant) external onlySurvey {
        participatedSurveys[_participant].push(msg.sender);
    }

    //Calculate EarningsOfParticipant
    function getEarningsUser(
        address _participant
    ) internal returns (uint totalEarnings) {
        uint totalAmount = 0;
        for (uint i = 0; i < participatedSurveys[_participant].length; i++) {
            if (surveyFinished[participatedSurveys[_participant][i]]) {
                totalAmount += SurveyUpgradable(
                    participatedSurveys[_participant][i]
                ).calculateEarnings(_participant);
                removeSurveyFromUser(_participant, i);
            }
        }
        return totalAmount;
    }

    //Participation of reviewers and participants will be stored in withdraw array
    function withdrawEarnings() external {
        uint userEarnings = getEarningsUser(msg.sender); //+removeitFromArray
        require(userEarnings > 0, "No pending earnings");
        (bool result, ) = payable(msg.sender).call{value: userEarnings}("");
        require(result, "Withdraw failed");
    }

    function removeSurveyFromUser(
        address _participant,
        uint _idxSurvey
    ) internal {
        participatedSurveys[_participant][_idxSurvey] = participatedSurveys[
            _participant
        ][participatedSurveys[_participant].length];
        participatedSurveys[_participant].pop();
    }

    //Function will be called by Survey after the End to remove it from the active surveys.
    function finishSuvery() external onlySurvey {
        surveyFinished[msg.sender] = true;
    }
}
