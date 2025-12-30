🚀 SpeedRun Ethereum Challenges

Repository này chứa mã nguồn giải pháp cho các challenge trong SpeedRun Ethereum.
Mỗi challenge được phát triển độc lập trên một nhánh (branch) riêng, giúp dễ quản lý, kiểm thử và submit từng bài.

📁 Cấu trúc Repository

Mỗi challenge tương ứng với một branch

Các challenge sử dụng chung framework Scaffold-ETH

Cấu trúc thư mục của các challenge là tương đồng

⚙️ Quy trình chạy code (Localhost)

Do các challenge có cấu trúc giống nhau, bạn có thể chạy bất kỳ challenge nào theo đúng quy trình dưới đây.

🔹 Bước 1: Clone & Cài đặt môi trường
git clone https://github.com/datmaster2004/challenge_speedruneth
yarn install

🔹 Bước 2: Chọn challenge cần chạy

Mỗi challenge nằm trên một nhánh riêng, cần checkout đúng nhánh trước khi chạy.

git checkout challenge-decentralized-staking
yarn install


⚠️ Lưu ý:
Luôn chạy lại yarn install sau khi chuyển nhánh để đảm bảo dependencies được cập nhật đúng.

🔹 Bước 3: Khởi chạy môi trường phát triển

Bạn cần mở 3 cửa sổ Terminal song song và chạy các lệnh sau:

🧩 Terminal 1: Khởi tạo Blockchain nội bộ 

yarn chain

🧩 Terminal 2: Compile & deploy Smart Contract

cd <challenge>
yarn deploy

🧩 Terminal 3: Chạy Frontend

cd <challenge>
yarn start


➡️ Sau khi hoàn tất, truy cập giao diện tại:
👉 http://localhost:3000

Tại đây bạn có thể tương tác với Smart Contract và hoàn thành các checkpoint của challenge.

🧪 Chạy Test tự động (Automated Testing)

Việc chạy test giúp kiểm tra logic Smart Contract mà không cần frontend.
Challenge được coi là hoàn thành khi toàn bộ test đều pass (màu xanh).

yarn test

🌐 Deploy lên Public Testnet (Sepolia)
🔹 Bước 1: Tạo ví deployer
yarn generate

🔹 Bước 2: Nạp ETH cho ví Sepolia

Ví mới tạo sẽ chưa có ETH. Bạn có thể sử dụng faucet sau để đào ETH mà không cần mainet:

https://sepolia-faucet.pk910.de/

🔹 Bước 3: Deploy Smart Contract lên Sepolia

yarn deploy --network sepolia

🔹 Bước 4: Verify Smart Contract

yarn verify --network sepolia

🔹 Bước 5: Deploy Frontend lên Vercel

yarn vercel
Contract URL

👉 Link Smart Contract trên Sepolia Etherscan


