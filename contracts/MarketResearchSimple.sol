pragma solidity ^0.8.0;

contract Survey {
    struct SurveyStruct {
        address creator;
        mapping(address => string[5]) answers;
        mapping(address => bool[10]) review;
    }
    mapping(uint => SurveyStruct) public surveys;
    event LogNewSurvey(address creator, uint surveyId);
    event LogAnswer(address respondent, uint surveyId);
    event LogReview(address reviewer, uint surveyId, bool success);
    event LogValidation(address creator, uint surveyId);

    uint public surveyCount;

    function createSurvey() public {
        address creator = msg.sender;
        uint surveyId = surveyCount++;
        surveys[surveyId].creator = creator;
        emit LogNewSurvey(creator, surveyId);
    }

    function answer(uint surveyId, string[5] memory answers) public {
        address respondent = msg.sender;
        surveys[surveyId].answers[respondent] = answers;
        emit LogAnswer(respondent, surveyId);
    }

    function review(
        uint surveyId,
        address respondent,
        bool[10] memory success
    ) public {
        address reviewer = msg.sender;
        surveys[surveyId].review[respondent][reviewer] = success;
        emit LogReview(reviewer, surveyId, success);
        if (validate(surveyId, respondent)) {
            emit LogValidation(surveys[surveyId].creator, surveyId);
        }
    }

    function validate(
        uint surveyId,
        address respondent
    ) internal view returns (bool) {
        uint totalSuccess = 0;
        for (uint i = 0; i < 10; i++) {
            if (surveys[surveyId].review[respondent][i]) {
                totalSuccess++;
            }
        }
        return totalSuccess >= 8;
    }

    function getValidAnswers(
        uint surveyId
    ) public view returns (address[] memory, string[5][] memory) {
        address creator = msg.sender;
        require(surveys[surveyId].creator == creator);
        address[] memory validRespondents = new address[](0);
        string[5][] memory validAnswers = new string[5][](0);
        address[] memory respondents = surveys[surveyId].answers.keys;
        for (uint i = 0; i < respondents.length; i++) {
            address respondent = respondents[i];
            if (validate(surveyId, respondent)) {
                validRespondents.push(respondent);
                validAnswers.push(surveys[surveyId].answers[respondent]);
            }
        }
        return (validRespondents, validAnswers);
    }
}
