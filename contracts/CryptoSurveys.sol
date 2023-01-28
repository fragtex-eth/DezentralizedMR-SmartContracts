//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract Survey {
    enum Vote {
        Poor, //0
        Fair,
        Average,
        Good,
        Excellent //4
    }
    enum Stage {
        Answer,
        Review,
        Completed
    }

    struct Question {
        string[] questions;
        address[] participants;
        address[] underReview;
        address[] validAnswers; //All participants with valid answers
        address[] inValidAnswers; //All participants with invalid answers
        uint hitReview;
        uint nextReview;
        mapping(address => uint) idxUnderReview;
        mapping(address => mapping(uint => string)) answers;
        mapping(address => Vote) participantResult;
        mapping(address => address[]) assignedReview;
        mapping(address => address) reviewAssigned;
        mapping(address => uint) resultReview; // Result of reviewer in uint;
        mapping(address => mapping(Vote => address[])) votesReview;
        mapping(address => bool) reviewers;
        mapping(address => uint) numberParticipentReviewed;
        mapping(address => bool) reviewed; //Reviewer has reviewed
    }

    Stage internal stage;
    Question internal question;
    uint256 public maxNumberOfParticipants;
    uint256 public reviewsNeeded;
    uint256 public deadlineTime;
    uint256 public capital;
    bool internal questionsSet = false;
    uint256 internal randNonce = 0;
    uint256 internal difference = 1;

    constructor(
        string[] memory _questions,
        uint256 _participants,
        uint256 _endTime,
        uint256 _reviewNeeded,
        uint256 _capital
    ) {
        question.questions = _questions;
        maxNumberOfParticipants = _participants;
        deadlineTime = _endTime;
        stage = Stage.Answer;
        reviewsNeeded = _reviewNeeded;
        capital = _capital;
    }

    function answerQuestions(
        string[] calldata _answers,
        address _participant
    ) external {
        require(question.participants.length < maxNumberOfParticipants);
        question.participants.push(_participant);
        for (uint i = 0; i < _answers.length; i++) {
            question.answers[_participant][i] = _answers[i];
            question.idxUnderReview[_participant] = question.underReview.length;
            question.underReview.push(_participant);
        }
        if (question.participants.length >= maxNumberOfParticipants) {
            stage = Stage.Review;
        }
    }

    function requestReview() external {
        question.reviewers[msg.sender] = true;
        uint idxParticipant = randomNumber(question.underReview.length);
        question.reviewAssigned[msg.sender] = question.underReview[
            idxParticipant
        ];
    }

    function reviewAnswers(address _reviewer, Vote _vote) external {
        require(!question.reviewed[_reviewer], "Already reviewed");
        address participant = question.reviewAssigned[_reviewer];
        question.reviewed[_reviewer] = true;
        question.votesReview[participant][_vote].push(_reviewer);
        question.numberParticipentReviewed[participant] += 1;
        if (question.numberParticipentReviewed[participant] >= reviewsNeeded) {
            reviewParticipantFinished(participant);
            completeReviewParticipant(participant);
        }
    }

    function calculateEarnings(
        address _beneficiary
    ) external view returns (uint earnings) {}

    function viewAnswers(
        address _participant,
        uint _questionNr
    ) external view returns (string memory) {
        require(stage == Stage.Completed);
        return question.answers[_participant][_questionNr];
    }

    function completeReviewParticipant(address _participant) internal {
        question.resultReview[_participant] = validateReviewer(_participant);
        if (question.resultReview[_participant] > ((reviewsNeeded * 15) / 10)) {
            question.validAnswers.push(_participant);
        } else {
            question.inValidAnswers.push(_participant);
        }
        allocateReviewers(
            _participant,
            question.participantResult[_participant]
        );
    }

    function getValidAnswers() external view returns (address[] memory) {
        require(stage == Stage.Completed);
        return question.validAnswers;
    }

    function reviewParticipantFinished(address _participant) internal {
        uint idxPartipant = question.idxUnderReview[_participant];
        if (idxPartipant < question.underReview.length - 1) {
            address lastParticipant = question.underReview[
                question.underReview.length - 1
            ];
            question.underReview[idxPartipant] = lastParticipant;
            question.idxUnderReview[lastParticipant] = idxPartipant;
        }
        question.underReview.pop();
        if (question.underReview.length == 0) {
            stage = Stage.Completed;
        }
    }

    function validateReviewer(
        address _participant
    ) internal returns (uint result) {
        uint totalPoints;
        for (uint i = 0; i < 5; i++) {
            totalPoints = (question.votesReview[_participant][Vote(i)].length *
                i);
        }
        totalPoints = (totalPoints * 10) / reviewsNeeded;
        Vote calcResult;

        if (totalPoints >= ((reviewsNeeded * 35) / 10)) {
            calcResult = Vote.Excellent;
        } else if (totalPoints >= ((reviewsNeeded * 25) / 10)) {
            calcResult = Vote.Good;
        } else if (totalPoints >= ((reviewsNeeded * 15) / 10)) {
            calcResult = Vote.Average;
        } else if (totalPoints >= ((reviewsNeeded * 5) / 10)) {
            calcResult = Vote.Fair;
        } else {
            calcResult = Vote.Poor;
        }
        question.participantResult[_participant] = calcResult;
        return totalPoints;
    }

    function allocateReviewers(address _participant, Vote _result) internal {
        question.hitReview += question
        .votesReview[_participant][_result].length; //Add number of winners to the winner cont
        uint8 idx = uint8(_result);

        for (uint i = 0; i < 5; i++) {
            if (i - idx == difference || idx - i == difference) {
                question.nextReview += question
                .votesReview[_participant][Vote(i)].length;
            }
        }
    }

    function randomNumber(uint _modulus) internal virtual returns (uint) {
        randNonce++;
        return
            uint(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        msg.sender,
                        randNonce,
                        _modulus
                    )
                )
            ) % _modulus;
    }
}
