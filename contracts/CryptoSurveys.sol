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
        string[] questions; //Array of the questions
        address[] participants; //Array of the participants
        address[] underReview; //Array of participants that have not been fully reviewed yet
        address[] validAnswers; //All participants with valid answers
        address[] inValidAnswers; //All participants with invalid answers
        uint hitReview; // Number of Reviewers that made the correct choice
        uint nextReview; // Amount of Reviewers that are close to the final choice receive 30% of the reward that hit users receive
        uint excellent; // Number of Reviewers that made the correct choice
        uint good;
        uint average; // Number of Reviewers that made the correct choice
        mapping(address => bool) isParticipant; //If address is participant
        mapping(address => bool) isReviewer; //If address is participant
        mapping(address => uint) idxUnderReview; //Indexin the UnderReview array of specific addresses
        mapping(address => bool) participantReviewed; //Address has been reviewed
        mapping(address => mapping(uint => string)) answers; //Given answers by the participants
        mapping(address => Vote) participantResult; //Result of the
        mapping(address => Vote) reviewVote;
        mapping(address => address[]) assignedReview;
        mapping(address => address) reviewAssigned; //Links Reviewee to participant that is assigned to him
        mapping(address => uint) resultReview; // Result of participant in uint;
        mapping(address => mapping(Vote => address[])) votesReview; //Participant mapping to each of the choices the reviewers took
        mapping(address => uint) numberParticipentReviewed; //Number of times a reviewer has been reviewed
        mapping(address => bool) rAssigned; //Participant has been assigned to reviewre
    }

    Stage internal stage;
    Question internal question;
    uint256 public maxNumberOfParticipants;
    uint256 public reviewsNeeded;
    uint256 public deadlineTime;
    uint256 public capitalParticipants;
    uint256 public capitalReview;
    uint256 internal randNonce = 0;
    uint256 internal constant DIFFERENCE = 1;

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
        capitalParticipants = (_capital * 100) / 70;
        capitalReview = _capital - capitalParticipants;
    }

    /**
     * @dev Function to answer the question
     *
     * @param _answers Survey answers
     * @param _participant Address participant
     */
    function answerQuestions(
        string[] calldata _answers,
        address _participant
    ) external {
        require(!question.isParticipant[_participant], "Already answerde");
        require(
            _answers.length == question.questions.length,
            "Number of answers have to be equal to the number of questions"
        );
        require(
            question.participants.length < maxNumberOfParticipants,
            "Participant limit reached"
        );
        question.isParticipant[_participant] = true;
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

    /**
     * @dev function to request a review
     * @notice has be called before answer can be reviewed/currently possible to surpass review limit, so might be able to request but not able to answer
     */
    function requestReview(address _reviewer) external {
        require(stage == Stage.Review, "Survey not in review stage");
        require(!question.rAssigned[_reviewer], "Already assigned");
        question.rAssigned[_reviewer] = true;
        uint idxParticipant = randomNumber(question.underReview.length);
        question.reviewAssigned[_reviewer] = question.underReview[
            idxParticipant
        ];
    }

    /**
     * @dev function to submit review
     * @param _reviewer address of the reviewer
     * @param _vote vote decision
     */
    function reviewAnswers(address _reviewer, Vote _vote) external {
        require(stage == Stage.Review, "Survey not in review stage");
        address participant = question.reviewAssigned[_reviewer];
        require(
            !question.participantReviewed[participant],
            "Maximum number of reviews already reached for the participant"
        );
        question.votesReview[participant][_vote].push(_reviewer);
        question.numberParticipentReviewed[participant] += 1;
        question.reviewVote[_reviewer] = _vote;
        question.isReviewer[_reviewer] = true;
        if (question.numberParticipentReviewed[participant] >= reviewsNeeded) {
            question.participantReviewed[participant] = true;
            reviewParticipantFinished(participant);
            completeReviewParticipant(participant);
        }
    }

    /**
     * @notice function to get the earings of an address
     * @param _beneficiary beneficiary earnings
     */
    function calculateEarnings(
        address _beneficiary
    ) external view returns (uint earnings) {
        if (question.isParticipant[_beneficiary]) {
            return
                calculateEarningsParticipant(
                    getIntVote(question.participantResult[_beneficiary])
                );
        } else if (question.isReviewer[_beneficiary]) {
            uint uintVote = getIntVote(question.reviewVote[_beneficiary]);
            address participantReviewed = question.reviewAssigned[_beneficiary];
            uint uintResult = getIntVote(
                question.participantResult[participantReviewed]
            );
            if (uintVote >= uintResult) {
                return calculateEarningsReviewer(uintVote - uintResult);
            } else {
                return calculateEarningsReviewer(uintResult - uintVote);
            }
        } else {
            return 0;
        }
    }

    function calculateEarningsReviewer(
        uint group //4 = hit, 3 = next, 2 = average
    ) internal view returns (uint earnings) {
        uint amountPerReviewer = capitalReview /
            (question.hitReview + ((30 * question.nextReview) / 100));
        if (group == 4) {
            return amountPerReviewer;
        } else if (group == 3) {
            return (amountPerReviewer * 50) / 100;
        } else if (group == 2) {
            return (amountPerReviewer * 20) / 100;
        } else {
            return 0;
        }
    }

    function calculateEarningsParticipant(
        uint group //0 = Excellent, 1 = Good, 2 = Average
    ) internal view returns (uint earnings) {
        uint amountPerParticipant = capitalParticipants /
            ((question.excellent + ((50 * question.good) / 100)) +
                ((20 * question.average) / 100));
        if (group == 0) {
            return amountPerParticipant;
        } else if (group == 1) {
            return (amountPerParticipant * 50) / 100;
        } else {
            return (amountPerParticipant * 20) / 100;
        }
    }

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
        uint totalPoints = 0;
        for (uint i = 0; i < 5; i++) {
            totalPoints = (question.votesReview[_participant][Vote(i)].length *
                i);
        }
        totalPoints = (totalPoints * 10) / reviewsNeeded;
        Vote calcResult;

        if (totalPoints >= ((reviewsNeeded * 35) / 10)) {
            calcResult = Vote.Excellent;
            question.excellent++;
        } else if (totalPoints >= ((reviewsNeeded * 25) / 10)) {
            calcResult = Vote.Good;
            question.good++;
        } else if (totalPoints >= ((reviewsNeeded * 15) / 10)) {
            calcResult = Vote.Average;
            question.average++;
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
            if (i - idx == DIFFERENCE || idx - i == DIFFERENCE) {
                question.nextReview += question
                .votesReview[_participant][Vote(i)].length;
            }
        }
    }

    function getIntVote(Vote votes) internal pure returns (uint _vote) {
        if (votes == Vote.Excellent) {
            return 4;
        } else if (votes == Vote.Good) {
            return 3;
        } else if (votes == Vote.Average) {
            return 2;
        } else if (votes == Vote.Fair) {
            return 1;
        } else if (votes == Vote.Poor) {
            return 0;
        }
    }

    /**
     * @notice PRNG, could be manipulated theoretically hower in this case would not have a big impact as it would only have a minimum impact on the result.
     * @param _modulus Range of random number
     */
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
