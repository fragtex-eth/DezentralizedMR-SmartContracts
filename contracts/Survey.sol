//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IFactorContract {
    function finishSuvery() external;

    function enterReviewSurvey() external;

    function addSurveyCompleted(address _participant) external;
}

contract Survey {
    IFactorContract public factoryC;

    string public name;
    string[] public questions;
    uint256 public maxNumberOfParticipants; //Maximum number of participants
    uint256 public reviewsNeeded; //Number of evaluations needed
    uint256 public endTime; //EndTime when survey can be closed
    uint256 public capitalParticipants; //Capital allocation for the participants
    uint256 public capitalReview; //Capital allocated for the reviewers
    address public owner;

    bool questionsSet; //If questions are already initalized
    uint256 internal randNonce;
    uint256 internal constant DIFFERENCE = 1;

    struct Question {
        string[] questions; //Array of questions
        address[] participants; //Array of participants
        address[] underReview; //Array of participants that have not been fully reviewed yet
        address[] validAnswers; //All participants with valid answers
        address[] inValidAnswers; //All participants with invalid answers
        uint hitReview; // Number of reviewers that made the correct choice
        uint nextReview; // Number of reviewers that are close to the "correct" choice
        uint excellent; // Number of reviewers that made the correct choice
        uint good;
        uint average; // Number of reviewers that made the correct choice
        mapping(address => bool) isParticipant; //If address is participant
        mapping(address => bool) isReviewer; //If address is reviewer
        mapping(address => uint) idxUnderReview; //Index in the UnderReview array of address
        mapping(address => bool) participantReviewed; //If participant has been reviewed
        mapping(address => mapping(uint => string)) answers; //Answers by the participants
        mapping(address => Vote) participantResult;
        mapping(address => Vote) reviewVote;
        mapping(address => address[]) assignedReview;
        mapping(address => address) reviewAssigned; //Participant that is asigned to reviewee
        mapping(address => uint) resultReview; // Result of participant in uint;
        mapping(address => mapping(Vote => address[])) votesReview; //Participant assignment to each of the selections made by the reviewers.
        mapping(address => uint) numberParticipentReviewed; //Number of times a participant has been reviewed.
        mapping(address => bool) rAssigned; //If participant was assigned to a reviewer
    }

    Question internal question;

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

    Stage public stage;

    event StageChanged(Stage);

    modifier onlyOwner() {
        require(owner == msg.sender, "Not allowed to call the function");
        _;
    }

    /**Contract cannot be initialized directly */
    constructor() {
        owner = address(0xdead);
    }

    function initialize(
        string memory _name,
        uint256 _participants,
        uint256 _endTime,
        uint256 _reviewNeeded,
        uint256 _capital
    ) external {
        require(owner == address(0), "Forbidden");
        owner = msg.sender;
        name = _name;
        maxNumberOfParticipants = _participants;
        endTime = block.timestamp + _endTime;
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
     * @param _answers survey answers
     */
    function answerQuestions(string[] calldata _answers) external {
        address _participant = msg.sender;
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
     * @notice must be called before the response can be checked
     * */
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
     * @notice Return participant that is assigned to the reviewer.
     * @param _reviewer Address of the reviewer
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
     * @notice Function to determine the earnings of an address.
     * @param _beneficiary address of beneficiary
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
     * Close the survey manual if there are not enough participants.
     */
    function closeSurvey() external onlyOwner {
        require(stage != Stage.Completed);
        factoryC.finishSuvery();
        stage = Stage.Completed;
    }

    /**
     * Returns the current stage
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

    /**
     * Display a response from a participant
     * @param _participant Address of the participant
     * @param _questionNr Index of the address (0-4)
     */
    function viewAnswers(
        address _participant,
        uint _questionNr
    ) external view returns (string memory) {
        require(stage == Stage.Completed || stage == Stage.Review);
        return question.answers[_participant][_questionNr];
    }

    /**
     * Returns valid answers
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
     * @notice PRNG, could theoretically be manipulated, but would not have much impact in this case as it would have minimal effect on the result.
     * @param _modulus range of random number.
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
