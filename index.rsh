"reach 0.1";
const obj = Object({
  userNum: UInt,
  raffle: UInt,
  address: Address,
});
const MObj = Maybe(obj);
const MAddr = Maybe(Address);

const TICKET_NUMBER = 5;

const [whoWon, NO_WIN, A_BOB_WON] = makeEnum(2);
const common = {
  notify: Fun([UInt], Null),
  showWinner: Fun([obj], Null),
};

export const main = Reach.App(() => {
  setOptions({ untrustworthyMaps: true });
  const A = Participant("Alice", {
    // Specify Alice's interact interface here
    ...hasRandom,
    NftID: Token,
    ticketAmount: UInt,
    ready: Fun([UInt], Null),
    ...common,
  });
  const B = Participant("Bob", {
    // Specify Bob's interact interface here
    ...common,
  });
  const V = View("V", {
    view: MObj,
  });

  const C = API("Caller", {
    getRandom: Fun(
      [],
      Object({
        userNum: UInt,
        raffle: UInt,
        address: Address,
      })
    ),
    alert: Fun([], Null),
  });

  init();
  // The first one to publish deploys the contract
  A.only(() => {
    const nft = declassify(interact.NftID);
    // We get a random number using reach inbuilt method
    // We sppecify that the number is between 0 & TICKET_NUMBER
    const arrayOfTickets = array(UInt, [1, 7, 20, 500, 2]);

    const _num = interact.random() % TICKET_NUMBER;

    const [_randomNumber, _salt] = makeCommitment(interact, _num);
    const winningNumber = declassify(_randomNumber);
  });
  A.publish(nft, winningNumber, arrayOfTickets);
  commit();
  A.pay([[1, nft]]);
  const userNum = new Map(UInt);

  A.interact.ready(TICKET_NUMBER);
  commit();
  B.publish();


  // This will serve as placeholder for the winner
  const aliceDetails = {
    userNum: 0,
    raffle: TICKET_NUMBER + 1,
    address: A,
  };
  // ! Creating our repeatable Parallel reduce

  const reusableFunction = () => {
    const [numberOfUsers, keepGoing, arrayOfUsers, winningAddress] =
      parallelReduce([
        0,
        true,
        Array.replicate(TICKET_NUMBER, aliceDetails),
        MObj.None(null),
      ])
        .invariant(balance(nft) == 1)
        .while(keepGoing)
        .case(
          A,
          () => ({
            when: numberOfUsers == TICKET_NUMBER,
          }),
          (_) => {
            commit();
            A.only(() => {
              const raffleNumber = declassify(_num);
              const raffleSalt = declassify(_salt);
              interact.notify(numberOfUsers);
            });
            A.publish(raffleNumber, raffleSalt);
            checkCommitment(winningNumber, raffleSalt, raffleNumber);

            const getWinner = () => {
              const idx = arrayOfUsers.findIndex(
                ({ raffle }) => raffle == raffleNumber
              );
              return arrayOfUsers[fromSome(idx, TICKET_NUMBER - 1)];
            };

            const winner = getWinner();

            each([A, B], () => interact.showWinner(winner));

            return [numberOfUsers, false, arrayOfUsers, MObj.Some(winner)];
          }
        )
        .define(() => {
          V.view.set(winningAddress);
        })
        .api(
          C.getRandom,
          () => {
            check(isNone(userNum[this]), "You can only call once");
            check(
              (numberOfUsers <= TICKET_NUMBER),
              "Exceeded amount, Try claiming instead"
            );
          },
          () => 0,
          (k) => {
            userNum[this] = arrayOfTickets[numberOfUsers % TICKET_NUMBER];
            const newArray = arrayOfUsers.set(numberOfUsers % TICKET_NUMBER, {
              raffle: arrayOfTickets[numberOfUsers % TICKET_NUMBER],
              address: this,
              userNum: numberOfUsers,
            });
            k(newArray[numberOfUsers % TICKET_NUMBER]);
            return [numberOfUsers + 1, keepGoing, newArray, winningAddress];
          }
        )

        .timeout(relativeTime(2000), () => {
          const [[], k] = call(C.alert);
          k(null);
          return [numberOfUsers, keepGoing, arrayOfUsers, winningAddress];
        });
    return [numberOfUsers, keepGoing, arrayOfUsers, winningAddress];
  };

  const [numberOfUsers, keepGoing, arrayOfUsers, winningAddress] =
    reusableFunction();

  
  // const outcome = randomNumber == bobNumber;
  const outcome = true;

  transfer(balance(nft), nft).to(
    fromSome(winningAddress, aliceDetails).address
  );
  transfer(balance()).to(A);
  commit();
  exit();
});
