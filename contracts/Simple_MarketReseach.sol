pragma solidity ^0.8.0;

contract Survey {
    struct Question {
        string question;
        string[] answers;
        mapping(address => uint) votes;
    }
    mapping(uint => Question) public questions;
    mapping(uint => answers[]) public 
    uint public questionCount;
    event LogNewQuestion(address creator, uint questionId);
    event LogAnswer(address respondent, uint questionId, uint answerId);

    function newQuestion(
        string memory question,
        string[] memory answers
    ) public {
        require(answers.length == 4);
        address creator = msg.sender;
        uint questionId = questionCount++;
        Question memory questionArray = Question({
            question: question,
            answers: answers,
            votes: 0
        });
        questions[questionId] = Question({
            question: question,
            answers: answers
        });
        emit LogNewQuestion(creator, questionId);
    }

    function answer(uint questionId, uint answerId) public {
        address respondent = msg.sender;
        require(answerId < 4);
        questions[questionId].votes[respondent] = answerId;
        emit LogAnswer(respondent, questionId, answerId);
    }

    function getAnswers(
        uint questionId
    ) public view returns (string[] memory, mapping(address => uint) memory) {
        address creator = msg.sender;
        require(questions[questionId].creator == creator);
        return (questions[questionId].answers, questions[questionId].votes);
    }
}
