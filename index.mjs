import { loadStdlib, ask } from "@reach-sh/stdlib";
import * as backend from "./build/index.main.mjs";

let API_NUMBER = 0;

if (
  process.argv.length < 3 ||
  ["Alice", "Bob"].includes(process.argv[2]) == false
) {
  console.log("Usage: reach run index [Alice|Bob]");
  process.exit(0);
}
const role = process.argv[2];

const stdlib = loadStdlib(process.env);

const startingBalance = stdlib.parseCurrency(1000);

const getBal = async (acc) => {
  const bal = parseInt(await stdlib.balanceOf(acc, nft.id));
  return bal;
};

const [accAlice, accBob] = await stdlib.newTestAccounts(2, startingBalance);
role == "Alice"
  ? console.log("Creating NFT")
  : console.log("Hope you feeling lucky , Cus you might win an NFT");
const nft = await stdlib.launchToken(accAlice, "Reach token", "RCH", {
  supply: 1,
  decimals: 1,
});
// Helper function to view winner
const viewWinner = (ctc) => {
  const view = ctc.V.view();
  console.log(view);
};
console.log("NFT created successfully");
accBob.tokenAccept(nft.id);
console.log("Hello, Alice and Bob!");

console.log("Launching...");

const common = {
  notify: async (item) => {
    console.log(parseFloat(item));
    return;
  },
  showWinner: (Obj) => {
    console.log("The raffle winner details are");
    console.table({
      assigned_raffle_number: parseInt(Obj.raffle),
      API_NUMBER: parseInt(Obj.userNum),
      address: Obj.address,
    });
    return;
  },
};

const CallApi = async (Info) => {
  try {
    const acc = await stdlib.newTestAccount(startingBalance);
    const ctc = acc.contract(backend, Info);
    const your_random_number = stdlib.hasRandom.random() % 5;
    const { address, raffle, userNum } = await ctc.apis.Caller
      .getRandom
      // your_random_number
      ();
    const val = await getBal(acc);
    const Nft_balance = `${val} RCH Tokens`;
    // console.table({ API_NUMBER, your_random_number,yourInfo, Nft_balance, });
    console.table({
      API_NUMBER: parseInt(userNum),
      your_assigned_number: parseInt(raffle),
      Nft_balance,
    });
    API_NUMBER++;
  } catch (error) {
    console.log(error);
  }
};

console.log("Starting backends...");

if (role == "Alice") {
  const val = await getBal(accAlice);
  const aliceBalanceBefore = `${val} RCH tokens`;

  const ctc = accAlice.contract(backend);
  await Promise.all([
    backend.Alice(ctc, {
      ...stdlib.hasRandom,
      ...common,
      NftID: nft.id,

      ready: async (numberOFTickets) => {
        console.log(`Contract info: ${JSON.stringify(await ctc.getInfo())}`);
        console.log({ numberOFTickets: parseInt(numberOFTickets) });
      },
      // implement Alice's interact object here
    }),
    backend.Bob(ctc, {
      ...stdlib.hasRandom,
      ...common,
      // implement Bob's interact object here
    }),
  ]);
  const val2 = await getBal(accAlice);
  const aliceBalanceAfter = `${val2} RCH tokens`;
  console.table({ aliceBalanceBefore, aliceBalanceAfter });
}
if (role == "Bob") {
  const info = await ask.ask("Paste contract info:", (s) => (s));
  const tickets = await ask.ask("How many Tickets:", (s) => parseInt(s));
  const ctc = accBob.contract(backend, info);

  // Create a map to call all the  API instances
  const fullFillPromises = Array(tickets)
    .fill(0)
    .map(() => CallApi(info));
  await Promise.all(fullFillPromises);

  await getBal(accBob, true);
}

ask.done();
console.log("Goodbye, Alice and Participants!");
