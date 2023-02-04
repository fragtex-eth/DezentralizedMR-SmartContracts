//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IFactorContract {
    function finishSuvery() external;

    function enterReviewSurvey() external;

    function addSurveyCompleted(address _participant) external;
}

contract Survey {
    enum Vote {
        Poor,
        Fair,
        Average,
        Good,
        Excellent
    }
    enum Stage {
        Question,
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

    Stage public stage;
    Question internal question;
    string[] public questions;
    uint256 public maxNumberOfParticipants; //maximal number of participants
    uint256 public reviewsNeeded; //number of reviews per participant
    uint256 public endTime; //EndTime when survey can be closed
    uint256 public capitalParticipants; //Capital assigned for the participants
    uint256 public capitalReview; //Capital assigned for the reviewers
    uint256 internal randNonce;
    uint256 internal constant DIFFERENCE = 1;
    bool questionsSet; //If questions are already initalized
    IFactorContract public factoryC;
    address public owner;
    event StageChanged(Stage);

    modifier onlyOwner() {
        require(owner == msg.sender, "No allowed to call the function");
        _;
    }

    /**Contact can't be initialized directly */
    constructor() {
        owner = address(0xdead);
    }

    function initialize(
        uint256 _participants,
        uint256 _endTime,
        uint256 _reviewNeeded,
        uint256 _capital
    ) external {
        require(owner == address(0), "Forbidden");
        owner = msg.sender;
        maxNumberOfParticipants = _participants;
        endTime = _endTime;
        reviewsNeeded = _reviewNeeded;
        capitalParticipants = (_capital * 30) / 100;
        capitalReview = _capital - capitalParticipants;
        randNonce = 0;
        stage = Stage.Question;
        factoryC = IFactorContract(msg.sender);
        emit StageChanged(stage);
    }

    function setQuestions(string[] memory _questions) external onlyOwner {
        require(!questionsSet, "Questions already set");
        questionsSet = true;
        question.questions = _questions;
        questions = _questions;
        stage = Stage.Answer;
        emit StageChanged(stage);
    }

    /**
     * @dev Function to answer the question
     *
     * @param _answers Survey answers
     */
    function answerQuestions(string[] calldata _answers) external {
        address _participant = msg.sender;
        //only be called by owner change after test
        require(!question.isParticipant[_participant], "Already answered");
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
        }
        question.idxUnderReview[_participant] = question.underReview.length;
        question.underReview.push(_participant);
        factoryC.addSurveyCompleted(_participant);
        if (question.participants.length >= maxNumberOfParticipants) {
            stage = Stage.Review;
            factoryC.enterReviewSurvey();
            emit StageChanged(stage);
        }
    }

    /**
     * @dev function to request a review
     * @notice has be called before answer can be reviewed/currently possible to surpass review limit, so might be able to request but not able to answer
     */
    function requestReview() external returns (address) {
        address _reviewer = msg.sender;
        require(stage == Stage.Review, "Survey not in review stage");
        require(!question.rAssigned[_reviewer], "Already assigned");
        question.rAssigned[_reviewer] = true;
        uint idxParticipant = randomNumber(question.underReview.length);
        question.reviewAssigned[_reviewer] = question.underReview[
            idxParticipant
        ];
        return question.reviewAssigned[_reviewer];
    }

    /**
     * @notice Return the participant that is assigned to the reviewer
     * @param _reviewer address of the reviewer
     */
    function returnReviewParticipant(
        address _reviewer
    ) external view returns (address) {
        return question.reviewAssigned[_reviewer];
    }

    /**
     * @dev function to submit review
     * @param _vote vote decision
     */
    function reviewAnswers(Vote _vote) external {
        address _reviewer = msg.sender;
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
        factoryC.addSurveyCompleted(_reviewer);
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
    ) external view onlyOwner returns (uint earnings) {
        require(stage == Stage.Completed);

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

    /**
     * Close survey manully in case there are not enough participants
     */
    function closeSurvey() external onlyOwner {
        require(stage != Stage.Completed);
        factoryC.finishSuvery();
        stage = Stage.Completed;
    }

    /**
     * Function that returns the current stage
     */
    function getStage() external view onlyOwner returns (uint currentStage) {
        if (stage == Stage.Question) {
            return 0;
        }
        if (stage == Stage.Answer) {
            return 1;
        }
        if (stage == Stage.Review) {
            return 2;
        }
        if (stage == Stage.Completed) {
            return 3;
        }
    }

    function calculateEarningsReviewer(
        uint _group //0 = hit, 1 = next, 2 = average
    ) internal view returns (uint earnings) {
        uint amountPerReviewer = capitalReview /
            (question.hitReview + ((30 * question.nextReview) / 100));
        if (_group == 0) {
            return amountPerReviewer;
        } else if (_group == 1) {
            return (amountPerReviewer * 30) / 100;
        } else {
            return 0;
        }
    }

    /**
     * View an answer of a participant
     * @param _participant address of participant
     * @param _questionNr index of address (0-4)
     */
    function viewAnswers(
        address _participant,
        uint _questionNr
    ) external view returns (string memory) {
        require(stage == Stage.Completed || stage == Stage.Review);
        return question.answers[_participant][_questionNr];
    }

    /**
     * Functon that returns valid answers
     */
    function getValidAnswers()
        external
        view
        onlyOwner
        returns (address[] memory)
    {
        require(stage == Stage.Completed);
        return question.validAnswers;
    }

    function calculateEarningsParticipant(
        uint _group //4 = Excellent, 3 = Good, 2 = Average
    ) internal view returns (uint earnings) {
        uint amountPerParticipant = capitalParticipants /
            ((4 * question.excellent) +
                (2 * question.good) +
                (question.average));
        //not divisible amount will stay on the contract
        if (_group == 4) {
            return 4 * amountPerParticipant;
        } else if (_group == 3) {
            return 2 * amountPerParticipant;
        } else if (_group == 2) {
            return amountPerParticipant;
        } else {
            return 0;
        }
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

    function reviewParticipantFinished(address _participant) internal {
        uint idxParticipant = question.idxUnderReview[_participant];
        if (idxParticipant < (question.underReview.length - 1)) {
            address lastParticipant = question.underReview[
                question.underReview.length - 1
            ];
            question.idxUnderReview[lastParticipant] = idxParticipant;
            question.underReview[idxParticipant] = lastParticipant;
        }

        question.underReview.pop();

        if (question.underReview.length == 0) {
            stage = Stage.Completed;
            factoryC.finishSuvery();
            emit StageChanged(stage);
        }
    }

    function validateReviewer(
        address _participant
    ) internal returns (uint result) {
        uint totalPoints = 0;
        for (uint i = 0; i < 5; i++) {
            totalPoints += (question.votesReview[_participant][Vote(i)].length *
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
            uint diff;
            if (i > idx) {
                diff = i - idx;
            } else {
                diff = idx - i;
            }
            if (diff == DIFFERENCE) {
                question.nextReview += question
                .votesReview[_participant][Vote(i)].length;
            }
        }
    }

    function getIntVote(Vote _votes) internal pure returns (uint _vote) {
        if (_votes == Vote.Excellent) {
            return 4;
        } else if (_votes == Vote.Good) {
            return 3;
        } else if (_votes == Vote.Average) {
            return 2;
        } else if (_votes == Vote.Fair) {
            return 1;
        } else if (_votes == Vote.Poor) {
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
