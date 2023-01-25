# Market Research Smart Contract
## Introduction
Decentralization has the potential to revolutionize market research by making it more accurate, transparent, and accessible. By removing intermediaries and distributing power among a network of users, decentralized systems can provide a more representative and diverse sample of opinions, resulting in more accurate data.
One of the key benefits of decentralization in market research is the ability to reach a wider and more diverse group of participants. Traditional market research relies on a centralized system where a small group of intermediaries control the data collection and analysis process. However, in a decentralized system, anyone can participate and contribute data, resulting in a more representative sample of the population. This is especially important for marginalized groups who are often underrepresented in traditional market research.

## Problem
### Security
Decentralized applications are built on blockchain technology, which means that they are vulnerable to hacking and other security threats. It is essential to ensure that the smart contract and the overall system are secure to protect the privacy and data of users.

### User Experience
Decentralized systems can be complex and difficult for non-technical users to navigate. The user experience needs to be designed in a way that is intuitive and easy to use, to make it accessible to a wide range of participants.

### Data Governance
Decentralized systems rely on a network of participants to contribute data. It is important to establish clear rules and guidelines for data governance, to ensure that the data is accurate and reliable.

### Incentivization
Incentivizing users to participate in market research can be a challenge in decentralized systems. It is important to find ways to incentivize users to contribute data, such as through rewards or tokens.

### Anonymity
In market research, protecting the identity of participants is crucial. It is important to establish a system that allows for anonymity while still providing accurate data.

## Solution
### Security
To ensure the security of a decentralized market research application, it is essential to use secure smart contract development practices and to conduct regular security audits. Additionally, implementing encryption and secure data storage methods can help protect user data.

### User Experience
To improve the user experience, the decentralized market research application should be designed with a simple and intuitive user interface, and provide clear instructions for users. Additionally, providing a mobile application for the platform, can also increase its accessibility.

### Data Governance
To ensure the quality and reliability of data in a decentralized market research application, it is essential to establish clear rules and guidelines for data governance. This can include measures such as data validation, data quality control, and data privacy protection.

### Incentivization
To incentivize users to participate in market research, the decentralized market research application can use tokens or other digital assets as rewards. Additionally, implementing a reputation system that rewards users for providing high-quality data can also be effective.

### Anonymity
To protect the anonymity of participants, the decentralized market research application can use zero-knowledge proofs or other privacy-preserving technologies to ensure that user data is kept private. Additionally, using a decentralized identity solution can help separate the identity of the participant from the data they provide, preserving anonymity.

## Solution

### Flow:
Creation -> Answers -> Review -> Result

Researcher creates questionaire and set budget and participants:
30% of the earnings go to creator 70% to reviewers

### Prerequisites
Identity confirmation for answerer, and reviewer

### Steps:
#### Creation of questionare
Researcher creates questionaire and sets budget and participants
Budget: 
- 30% -> Creator 
- 65% -> Reviewer
- 5% -> Plattform later DAO

#### Answers are distributed
User can request questionare and then have 10 minutes time to answer the questionare
After all the questions are answered go to review process:

#### Review process defines payout of creator:
Options (Payout creator defined):
1. Spam
2. Not accurate answer
3. Neutral
4. Good answer
5. Exceptional answer

#### Consensus
1. Round 1: 10 Reviewers -> 8 have to pick either (1,2 or 3,4) -> Median wins if not consent round 2:
2. Round 2: +10 Reviewers ->  15 have to pick either (1,2 or 3,4) -> Median wins if not consent round 3:
3. Round 3: +10 Reviewers -> 20 have to pick either (1,2 or 3,4)-> Median wins if not consent answer discarded

### End
1. Earnings due to malicious acting will be added on top of price pool
2. Researcher will receive answer
3. Payout for creator:
- Spam (-500%)
- Not accurate answer  (-100%)
- Neutral (0%)
- Good answer (100%)
- Exceptional answer (200%)

#### Payout for reviewers:
- Hit (100%)
- 1 next to hit (10%)
- 2 next to hit (-50%)
- 3 next to hit (-100%)

### Features MVP:
1. Create Survey with up to 5 questions: (Open question)
2. Only verified users can participate
3. Review Process (Good or Bad)
4. Consensus: 15/20
5. Distribution

