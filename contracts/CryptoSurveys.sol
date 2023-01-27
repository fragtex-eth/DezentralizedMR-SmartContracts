//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract Survey {
    enum Vote {
        Poor,
        Fair,
        Average,
        Good,
        Excellent
    }
    enum Stage {
        Answer,
        Review,
        Completed
    }

    struct Question {
        string[] questions;
        address[] participants;
        address[] validAnswers;
        mapping(address => mapping(uint => string)) answers;
        mapping(address => Vote) participantResult;
        mapping(address => address[]) assignedReview;
        mapping(address => mapping(Vote => address[])) votesReview;
        mapping(address => bool) reviewers;
        mapping(address => uint) numberParticipentReviewed;
        mapping(address => bool) tresholdReviewsReached;
        mapping(address => bool) reviewed; //Reviewer has reviewed
    }

    Stage internal stage;
    Question internal question;
    uint256 public maxNumberOfParticipants;
    uint256 public reviewsNeeded;
    uint256 public deadlineTime;
    bool internal questionsSet = false;

    constructor(
        string[] memory _questions,
        uint256 _participants,
        uint256 _endTime,
        uint256 _reviewNeeded
    ) {
        question.questions = _questions;
        maxNumberOfParticipants = _participants;
        deadlineTime = _endTime;
        stage = Stage.Answer;
        reviewsNeeded = _reviewNeeded;
    }

    function answerQuestions(
        string[] calldata _answers,
        address _participant
    ) external {
        require(question.participants.length < maxNumberOfParticipants);
        question.participants.push(_participant);
        for (uint i = 0; i < _answers.length; i++) {
            question.answers[_participant][i] = _answers[i];
        }
        if (question.participants.length >= maxNumberOfParticipants) {
            stage = Stage.Review;
        }
    }

    function reviewAnswers(
        address _reviewer,
        address _participant,
        Vote _vote
    ) external {
        require(!question.reviewed[_reviewer], "Already reviewed");
        question.reviewed[_reviewer] = true;
        question.votesReview[_participant][_vote].push(_reviewer);
        question.numberParticipentReviewed[_participant] += 1;
        if (question.numberParticipentReviewed[_participant] >= reviewsNeeded) {
            question.tresholdReviewsReached[_participant] = true;
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
        Vote result = question.participantResult[_participant];

        if (totalPoints >= ((reviewsNeeded * 35) / 10)) {
            result = Vote.Excellent;
        } else if (totalPoints >= ((reviewsNeeded * 25) / 10)) {
            result = Vote.Good;
        } else if (totalPoints >= ((reviewsNeeded * 15) / 10)) {
            result = Vote.Average;
        } else if (totalPoints >= ((reviewsNeeded * 5) / 10)) {
            result = Vote.Fair;
        } else {
            result = Vote.Poor;
        }
        return totalPoints;
    }

    function validAnswers() external {
        for (uint i = 0; i < question.participants.length; i++) {
            if (
                validateReviewer(question.participants[i]) >
                ((reviewsNeeded * 15) / 10)
            ) {
                question.validAnswers.push(question.participants[i]);
            }
        }
    }
}
