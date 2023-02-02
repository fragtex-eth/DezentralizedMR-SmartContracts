//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./SurveyUpgradable.sol";

contract SurveyFactory is Ownable {
    address public surveyImplementation;

    address[] public allSurveys;
    mapping(address => uint) public indexOfSurvey;

    constructor(address surveyImplementation) public {
        surveyImplementation = address(surveyImplementation);
    }

    function createSurvey(
        string[] memory _questions,
        uint256 _participants,
        uint256 _endTime,
        uint256 _reviewNeeded,
        uint256 _capital
    ) external returns (address survey) {
        address clone = Clones.clone(surveyImplementation);
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
    }
}
