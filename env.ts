import dotenv from 'dotenv';
dotenv.config();
export type Environment = {
    API_KEY: string;
    PRIVATE_KEY: string;
    MNEMONIC: string;
    MNEMONIC_PASSPHRASE: string;
    PRIVATE_KEYS: string[];
    DEFENDER_KEY: string;
    DEFENDER_SECRET: string;
}

const env = (): Environment => {
    const privateKeys = process.env.PRIVATE_KEYS?.split(",").filter(e => e);
    return {
        API_KEY: process.env.API_KEY as string,
        MNEMONIC: process.env.MNEMONIC as string,
        PRIVATE_KEY: process.env.PRIVATE_KEY as string,
        MNEMONIC_PASSPHRASE: process.env.MNEMONIC_PASSPHRASE as string,
        PRIVATE_KEYS: privateKeys || [],
        DEFENDER_KEY: process.env.DEFENDER_KEY as string,
        DEFENDER_SECRET: process.env.DEFENDER_SECRET as string
    }
};

export default env();
