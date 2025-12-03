# Install deps
npm install

# Run Hardhat tests
npx hardhat test

# Start local node
npx hardhat node

# In another terminal: run scripts
node scripts/deployAndMeasure.cjs
node scripts/scaletest.cjs

# Frontend
cd frontend
pnpm install
pnpm run dev