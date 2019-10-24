extern crate avro_rs;

#[macro_use]
extern crate serde_derive;
extern crate failure;
extern crate base64;

use avro_rs::{Codec, Schema, Writer, from_value, Reader, types::Record};
use failure::Error;
use std::vec::Vec;
use std::fs;
use std::io;
use base64::{encode, decode};
use parity_snappy as snappy;

#[derive(Debug, Deserialize, Serialize)]
struct Test {
   a: i64,
   b: String,
   link: String 
}

fn main() -> Result<(), Error> {
    
    let raw_schema = r#"
        {
            "type": "record",
            "name": "test",
            "fields": [
                {"name": "a", "type": "long", "default": 42},
                {"name": "b", "type": "string"},
                {"name": "link", "type": "string"}
            ]
        }
    "#;

    let schema = Schema::parse_str(raw_schema)?;
    
    //let mut writer = Writer::with_codec(&schema, Vec::new(), Codec::Snappy);
    let mut writer = Writer::with_codec(&schema, Vec::new(), Codec::Null);
    let mut record = Record::new(writer.schema()).unwrap();
    record.put("a", 27i64);
    record.put("b", "foo");
    record.put("link", "www.google.com");

    writer.append(record)?;

    writer.flush()?;
    
    let input = writer.into_inner();
    let comped = snappy::compress(&input);
    print_to_file(comped);
    read_avro_file(schema);
    Ok(())
}

fn read_avro_file(schema: Schema) -> Result<(), Error> {
    let compressedb64 = fs::read("avroData")?;
    let compressed = decode(&compressedb64)?;
    let decompressed = snappy::decompress(&compressed)?;
    let reader = Reader::with_schema(&schema, &decompressed[..])?;
    for record in reader {
        println!("{:?}", from_value::<Test>(&record?));
    }
    Ok(())
} 

fn print_to_file(avroData: Vec<u8>) {
    let base64Data = encode(&avroData);
    fs::write("avroData", &base64Data);
}

